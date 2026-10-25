import { Controller } from "@hotwired/stimulus"
import { copyableTodos } from "../lib/todos_copy"
import { t } from "../lib/translations"

// Fetches a scoped /todos.md body and copies it verbatim, so the
// clipboard holds exactly what the server returns. Success is only
// reported once real Markdown is on the clipboard (see lib/todos_copy).
export default class extends Controller {
  static values = { url: String }

  async copy() {
    try {
      const response = await fetch(this.urlValue)
      if (!copyableTodos({
        status: response.status,
        redirected: response.redirected,
        contentType: response.headers.get("Content-Type")
      })) {
        throw new Error(`Unexpected todos response: ${response.status}`)
      }

      const text = await response.text()
      await navigator.clipboard.writeText(text)
      window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("copied") } }))
    } catch (error) {
      console.error("Failed to copy todos", error)
      window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("todos.copy_failed") } }))
    }
  }
}
