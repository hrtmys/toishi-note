import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

// Fetches a scoped /todos.md body and copies it verbatim — the clipboard
// then holds exactly what the server would hand back, ids included,
// rather than a client-side reconstruction that could drift from it.
export default class extends Controller {
  static values = { url: String }

  async copy() {
    try {
      const response = await fetch(this.urlValue)
      const text = await response.text()
      await navigator.clipboard.writeText(text)
      window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("copied") } }))
    } catch (error) {
      console.error("Failed to copy todos", error)
    }
  }
}
