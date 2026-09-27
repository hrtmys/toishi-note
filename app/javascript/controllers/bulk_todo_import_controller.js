import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"
import { t } from "../lib/translations"
import { hideModal, installModalHideQueue } from "../lib/modal"

// Mirrors TodoPaste's grammar (app/models/todo_paste.rb). The modal only
// ever creates items, so an (id:) tag is discarded and a removal marker
// is rejected rather than honoured.
const TASK_LINE = /^- \[( |x)\] (.*)$/
const HEADING_LINE = /^##\s*(.*)$/
const ID_TAG = /^(.*?)\s*\(id:\s*([^)]*)\)$/
const DUE_TAG = /^(.*?)\s*\(due:\s*([^)]*)\)$/
const VALID_ID_BODY = /^([0-9a-z]+)(;delete!)?$/
const VALID_DUE_VALUE = /^(none|\d{4}-\d{2}-\d{2})$/

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
  if (deleting) return { kind: "task", valid: false, message: t("bulk_import.markdown_delete_unsupported", { raw: rawLine }) }

  const content = stripDueTag(withoutId).trim()
  if (!content) return { kind: "task", valid: false, raw: rawLine }

  return { kind: "task", valid: true, content, checked }
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

// Renders a live preview of a pasted JSON array or Markdown checklist of
// TODO tasks so a typo is visible before submitting. Convenience only —
// the server re-parses and re-validates independently.
export default class extends Controller {
  static targets = ["textarea", "preview", "error", "submit", "form"]

  connect() {
    this.modal = bootstrap.Modal.getOrCreateInstance(this.element)
    // Opens via data-bs-toggle, so no show() of ours — the show-event
    // half of the queue still guards against a stale hide on reopen.
    this.modalState = installModalHideQueue(this.element, () => this.modal)
  }

  preview() {
    const raw = this.textareaTarget.value.trim()

    if (raw === "") {
      this.reset()
      return
    }

    if (!raw.startsWith("[") && !raw.startsWith("{")) {
      const entries = parseMarkdownEntries(raw)
      // Nothing recognized as a heading or task line either — not
      // Markdown, not JSON, so report it the same way plain garbage
      // JSON does rather than leaving an unexplained empty preview.
      if (entries.length === 0) {
        this.showError(t("bulk_import.invalid_json"))
        return
      }

      this.renderPreview(entries)
      return
    }

    let parsed
    try {
      parsed = JSON.parse(raw)
    } catch (error) {
      this.showError(t("bulk_import.invalid_json"))
      return
    }

    if (!Array.isArray(parsed)) {
      this.showError(t("bulk_import.must_be_array"))
      return
    }

    this.renderPreview(parsed.map((entry) => this.classify(entry)))
  }

  classify(entry) {
    if (typeof entry === "string") {
      const content = entry.trim()
      return content ? { valid: true, content, checked: false } : { valid: false, raw: entry }
    }

    if (entry && typeof entry === "object" && !Array.isArray(entry)) {
      const content = typeof entry.content === "string" ? entry.content.trim() : ""
      if (content) {
        return { valid: true, content, checked: !!(entry.checked ?? entry.is_checked ?? entry.done) }
      }
    }

    return { valid: false, raw: entry }
  }

  renderPreview(entries) {
    this.errorTarget.classList.add("d-none")
    this.previewTarget.innerHTML = ""

    let validCount = 0

    entries.forEach((entry) => {
      const li = document.createElement("li")

      if (entry.kind === "heading") {
        li.className = "list-group-item list-group-item-secondary fw-semibold"
        li.textContent = entry.text
        this.previewTarget.appendChild(li)
        return
      }

      li.className = "list-group-item d-flex align-items-center gap-2"

      if (entry.valid) {
        validCount += 1
        const checkbox = document.createElement("input")
        checkbox.type = "checkbox"
        checkbox.className = "form-check-input"
        checkbox.disabled = true
        checkbox.checked = entry.checked

        const label = document.createElement("span")
        label.textContent = entry.content

        li.append(checkbox, label)
      } else {
        li.classList.add("list-group-item-danger")

        const icon = document.createElement("i")
        icon.className = "bi bi-exclamation-triangle-fill"

        const label = document.createElement("span")
        label.textContent = entry.message ?? t("bulk_import.skipped_invalid_task", { raw: JSON.stringify(entry.raw) })

        li.append(icon, label)
      }

      this.previewTarget.appendChild(li)
    })

    this.submitTarget.disabled = validCount === 0
  }

  showError(message) {
    this.previewTarget.innerHTML = ""
    this.submitTarget.disabled = true
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("d-none")
  }

  reset() {
    this.previewTarget.innerHTML = ""
    this.submitTarget.disabled = true
    this.errorTarget.classList.add("d-none")
  }

  // Only close and clear the modal once the import actually went through —
  // a failed request (e.g. a dropped connection) should leave the pasted
  // JSON in place so nothing is lost.
  submitEnd(event) {
    if (event.detail.success) {
      this.formTarget.reset()
      this.reset()
      hideModal(this.modalState, this.modal)
    }
  }
}
