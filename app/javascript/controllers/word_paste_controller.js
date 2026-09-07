import { Controller } from "@hotwired/stimulus"
import { convertHtmlToMarkdown, looksLikeRichContent, looksLikeTable } from "../lib/html_to_markdown"
import { t } from "../lib/translations"

// Detects real clipboard HTML and auto-converts Word's rich text to
// Markdown. Excel/Sheets ranges are deliberately not auto-converted;
// Ctrl+V falls through to image-upload's handler, the safe default.
export default class extends Controller {
  paste(event) {
    const html = event.clipboardData?.getData("text/html")
    if (!html || !looksLikeRichContent(html)) return

    if (looksLikeTable(html)) {
      this.dispatch("table-pasted", { detail: { html }, bubbles: true })
      return
    }

    const markdown = convertHtmlToMarkdown(html)
    if (!markdown) return

    event.preventDefault()
    // A Word selection can carry an embedded picture alongside the HTML.
    // Let image-upload's handler run too so the picture is uploaded
    // instead of silently dropped; with no image aboard there is nothing
    // left for it to do, so stop the event there.
    if (!hasImageItem(event)) event.stopImmediatePropagation()
    this.insertAtCursor(markdown)
    window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("converted_to_markdown") } }))
  }

  insertAtCursor(text) {
    const textarea = this.element
    const start = textarea.selectionStart ?? textarea.value.length
    const end = textarea.selectionEnd ?? textarea.value.length

    textarea.setRangeText(text, start, end, "end")
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }
}

// Mirrors image-upload's trigger: a clipboard item whose type starts
// with "image/" means a picture came along with the HTML paste.
function hasImageItem(event) {
  return Array.from(event.clipboardData?.items || []).some((item) => item.type.startsWith("image/"))
}
