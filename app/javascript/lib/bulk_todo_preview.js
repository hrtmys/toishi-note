// Mirrors TodoPaste's lenient grammar (app/models/todo_paste.rb), including parseTaskTags,
// pinned by test/shared/todo_paste_cases.json. The modal only creates items, so an
// (id:) tag is discarded and a removal marker is rejected, not honoured.
const TASK_LINE = /^[ \t]*(?:[-*+]|\d{1,9}[.)]) \[( |x|X)\] (.*)$/
const HEADING_LINE = /^#{1,6} (.*)$/
const TAG = /^(.*?)[ \t\r\n\f\v]*(?:\((id|due):[ \t\r\n\f\v]*([^)]*)\)|（(id|due):[ \t\r\n\f\v]*([^）]*)）)$/is
const VALID_ID_BODY = /^([0-9a-z]+)(;delete!)?$/
const DUE_SHAPE = /^\d{4}-\d{2}-\d{2}$/
const MAX_SKIPPED_SHOWN = 5

// Convenience only: the server re-parses and re-validates independently.
export function previewBulkEntries(raw, { max = Infinity } = {}) {
  const text = raw.trim()
  if (text === "") return result("empty")

  if (!text.startsWith("[") && !text.startsWith("{")) {
    const entries = parseMarkdownEntries(text)
    // Prose alone has no heading or task line, so it is reported the same
    // way garbage JSON is reported rather than as a list of skipped lines.
    const recognized = entries.some((e) => e.kind === "heading" || e.kind === "task")
    return recognized ? result("ok", null, entries, max) : result("error", "invalid_json")
  }

  let parsed
  try {
    parsed = JSON.parse(text)
  } catch (_) {
    return result("error", "invalid_json")
  }

  if (!Array.isArray(parsed)) return result("error", "must_be_array")

  return result("ok", null, parsed.map(classifyJsonEntry), max)
}

function result(status, error = null, entries = [], max = Infinity) {
  const validCount = entries.filter((e) => e.kind === "task" && e.valid).length
  const tooMany = validCount > max
  return tooMany
    ? { status, error, entries, validCount, tooMany, count: validCount, max }
    : { status, error, entries, validCount, tooMany }
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

// Mirrors TodoPaste#extract_tags: the same right-to-left scan, binding rules and
// content. Returns the content with consumed tags removed, plus the bound id,
// due ("none", YYYY-MM-DD or null) and whether the bound id carries ;delete!.
export function parseTaskTags(rest) {
  const ids = []
  const dues = []
  let literalDue = false
  let stop = rest.length

  for (;;) {
    const match = rest.slice(0, stop).match(TAG)
    if (!match) break

    const key = (match[2] ?? match[4]).toLowerCase()
    const body = match[3] ?? match[5]
    const start = match[1].length

    if (key === "id") {
      const valid = body.match(VALID_ID_BODY)
      if (!valid) break

      ids.push({ start, stop, id: parseInt(valid[1], 36), deleting: !!valid[2] })
    } else {
      if (literalDue || dues.length > 0) break

      const due = parseDue(body)
      if (due === null) literalDue = true
      else dues.push({ start, stop, due })
    }

    stop = start
  }

  const boundId = ids.length === 1 ? ids[0] : null
  const boundDue = dues[0] ?? null
  const consumed = [ boundId, boundDue ].filter(Boolean).sort((a, b) => b.start - a.start)

  let content = rest
  for (const span of consumed) content = content.slice(0, span.start) + content.slice(span.stop)

  return {
    content: trimAsciiSpace(content),
    id: boundId ? boundId.id : null,
    due: boundDue ? boundDue.due : null,
    deleting: boundId ? boundId.deleting : false,
  }
}

// Returns "none", the date itself when it names a real calendar day, or null.
function parseDue(value) {
  if (value === "none") return "none"
  if (!DUE_SHAPE.test(value)) return null

  const [ year, month, day ] = value.split("-").map(Number)
  const date = new Date(0)
  date.setUTCFullYear(year, month - 1, day)
  const real = date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day
  return real ? value : null
}

// Ruby's strip removes only ASCII whitespace; JS trim() also removes U+3000 and NBSP.
function trimAsciiSpace(text) {
  return text.replace(/^[ \t\r\n\f\v]+|[ \t\r\n\f\v]+$/g, "")
}

function classifyMarkdownTask(checked, rest, rawLine) {
  const tags = parseTaskTags(rest)
  if (tags.deleting) return invalidTask(rawLine, "delete_unsupported")

  const content = tags.content
  return content ? validTask(content, checked) : invalidTask(rawLine)
}

// Same skip rules as TodoPaste#parse!: <details> blocks and the
// "## Structure" section are dropped entirely, not shown as invalid.
function parseMarkdownEntries(text) {
  const entries = []
  let mode = "normal"
  let shownSkipped = 0
  let hiddenSkipped = 0

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
    if (taskMatch) {
      entries.push(classifyMarkdownTask(taskMatch[1] !== " ", taskMatch[2], line))
      continue
    }

    const trimmed = line.trim()
    if (trimmed === "") continue

    if (shownSkipped < MAX_SKIPPED_SHOWN) {
      entries.push({ kind: "skipped", text: trimmed })
      shownSkipped += 1
    } else {
      hiddenSkipped += 1
    }
  }

  if (hiddenSkipped > 0) entries.push({ kind: "more_skipped", count: hiddenSkipped })
  return entries
}
