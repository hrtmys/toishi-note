import { Controller } from "@hotwired/stimulus"
import { copyAsWordRichText } from "../lib/word_clipboard"
import { t } from "../lib/translations"

export default class extends Controller {
  static targets = ["button", "icon"]

  async copy() {
    const markdown = this.element.closest("[data-controller~='editor']")?.querySelector("textarea[name='note[content]']")?.value

    if (markdown == null) {
      this.showError()
      return
    }

    this.setBusy(true)

    try {
      await copyAsWordRichText(markdown)
      this.showSuccess()
    } catch (error) {
      console.error("Failed to copy rich text", error)
      this.showError()
    } finally {
      window.setTimeout(() => this.setBusy(false), 1500)
    }
  }

  setBusy(busy) {
    if (!this.hasButtonTarget) return

    this.buttonTarget.disabled = busy
    this.buttonTarget.classList.toggle("disabled", busy)
  }

  showSuccess() {
    window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("copied") } }))
    this.flashIcon("bi-check2", t("word_copy.success_title"))
  }

  showError() {
    this.flashIcon("bi-exclamation-triangle", t("word_copy.error_title"))
  }

  // Swaps just the icon/title, not the button's whole innerHTML — the
  // button carries a visible label now, which full innerHTML would wipe.
  flashIcon(iconClass, title) {
    if (!this.hasIconTarget || !this.hasButtonTarget) return

    const originalIconClass = this.iconTarget.className
    const originalTitle = this.buttonTarget.title

    this.iconTarget.className = `bi ${iconClass}`
    this.buttonTarget.title = title

    window.setTimeout(() => {
      this.iconTarget.className = originalIconClass
      this.buttonTarget.title = originalTitle
    }, 1500)
  }
}
