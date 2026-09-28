// Mirrors TodoPaste's grammar (app/models/todo_paste.rb). The modal only
// ever creates items, so an (id:) tag is discarded and a removal marker
// is rejected rather than honoured.
const TASK_LINE = /^- \[( |x)\] (.*)$/
const HEADING_LINE = /^##\s*(.*)$/
const ID_TAG = /^(.*?)\s*\(id:\s*([^)]*)\)$/
const DUE_TAG = /^(.*?)\s*\(due:\s*([^)]*)\)$/
const VALID_ID_BODY = /^([0-9a-z]+)(;delete!)?$/
const VALID_DUE_VALUE = /^(none|\d{4}-\d{2}-\d{2})$/

// Convenience only: the server re-parses and re-validates independently.
export function previewBulkEntries(raw) {
  const text = raw.trim()
  if (text === "") return result("empty")

  if (!text.startsWith("[") && !text.startsWith("{")) {
    const entries = parseMarkdownEntries(text)
    // Nothing recognized as a heading or task line either, so report it
    // the same way garbage JSON is reported.
    return entries.length === 0 ? result("error", "invalid_json") : result("ok", null, entries)
  }

  let parsed
  try {
    parsed = JSON.parse(text)
  } catch (_) {
    return result("error", "invalid_json")
  }

  if (!Array.isArray(parsed)) return result("error", "must_be_array")

  return result("ok", null, parsed.map(classifyJsonEntry))
}

function result(status, error = null, entries = []) {
  const validCount = entries.filter((e) => e.kind === "task" && e.valid).length
  return { status, error, entries, validCount }
}

function classifyJsonEntry(entry) {
  if (typeof entry === "string") {
    const content = entry.trim()
    return content ? validTask(content, false) : invalidTask(entry)
  }

  if (entry && typeof entry === "object" && !Array.isArray(entry)) {
    const content = typeof entry.content === "string" ? entry.content.trim() : ""
    if (content) return validTask(content, !!(entry.checked ?? entry.is_checked ?? entry.done))
  }

  return invalidTask(entry)
}

function validTask(content, checked) {
  return { kind: "task", valid: true, content, checked }
}

function invalidTask(raw, reason = "invalid") {
  return { kind: "task", valid: false, reason, raw }
}

function extractIdTag(rest) {
  const match = rest.match(ID_TAG)
  if (!match) return { content: rest, deleting: false }

  const [ , pre, body ] = match
  const valid = body.match(VALID_ID_BODY)
  if (!valid) return { content: rest, deleting: false }

  return { content: pre, deleting: !!valid[2] }
}

function stripDueTag(content) {
  const match = content.match(DUE_TAG)
  if (!match) return content

  const [ , pre, value ] = match
  return VALID_DUE_VALUE.test(value) ? pre : content
}

function classifyMarkdownTask(checked, rest, rawLine) {
  const { content: withoutId, deleting } = extractIdTag(rest)
  if (deleting) return invalidTask(rawLine, "delete_unsupported")

  const content = stripDueTag(withoutId).trim()
  return content ? validTask(content, checked) : invalidTask(rawLine)
}

// Same skip rules as TodoPaste#parse!: <details> blocks and the
// "## Structure" section are dropped entirely, not shown as invalid.
function parseMarkdownEntries(text) {
  const entries = []
  let mode = "normal"

  for (const line of text.split(/\r\n|\r|\n/)) {
    if (mode === "in_details") {
      if (line.includes("</details>")) mode = "normal"
      continue
    }

    if (line.includes("<details>")) {
      mode = "in_details"
      continue
    }

    const headingMatch = line.match(HEADING_LINE)
    if (headingMatch) {
      const title = headingMatch[1].trim()
      mode = title === "Structure" ? "in_structure" : "normal"
      if (mode === "normal" && title) entries.push({ kind: "heading", text: title })
      continue
    }

    if (mode === "in_structure") continue

    const taskMatch = line.match(TASK_LINE)
    if (taskMatch) entries.push(classifyMarkdownTask(taskMatch[1] === "x", taskMatch[2], line))
  }

  return entries
}
