import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

// Disables the add button while a submission is pending, and clears the form
// only after it succeeds, so a failed add keeps the typed text.
export default class extends Controller {
  static targets = [ "submit" ]

  submitStart() {
    if (!this.hasSubmitTarget) return

    this.originalLabel = this.submitTarget.value
    this.submitTarget.disabled = true
    this.submitTarget.value = t("forms.adding")
  }

  submitEnd(event) {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.value = this.originalLabel
    }

    if (event.detail.success) {
      this.element.reset()
    } else {
      window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("forms.add_failed") } }))
    }
  }

  // Submits the form on Ctrl+Enter (Cmd+Enter on Mac).
  submit(event) {
    event.preventDefault()
    if (this.submitTarget.disabled) return
    this.element.requestSubmit()
  }
}