import { Controller } from "@hotwired/stimulus"
import { convertHtmlToMarkdown } from "../lib/html_to_markdown"
import { t } from "../lib/translations"

// The FAB counterpart to word_paste_controller.js's Word conversion:
// converts the most recently pasted Excel table to Markdown on demand.
// Listens for its bubbling "table-pasted" event since it's a DOM sibling.
export default class extends Controller {
  cache(event) {
    this.pendingHtml = event.detail.html
  }

  convert() {
    if (!this.pendingHtml) {
      window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("table_paste.no_pending_table") } }))
      return
    }

    const textarea = this.element.closest("[data-controller~='editor']").querySelector("textarea[data-editor-target='textarea']")
    if (!textarea) return

    const markdown = convertHtmlToMarkdown(this.pendingHtml)
    this.pendingHtml = null // one-shot — a stale conversion re-inserted later would be surprising
    if (!markdown) return

    const start = textarea.selectionStart ?? textarea.value.length
    const end = textarea.selectionEnd ?? textarea.value.length
    textarea.setRangeText(markdown, start, end, "end")
    textarea.dispatchEvent(new Event("input", { bubbles: true }))

    window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("converted_to_markdown") } }))
  }
}
