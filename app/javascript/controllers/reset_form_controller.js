import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

// Used on the small "add TODO" / "add scrap" forms: disables the submit
// button for the duration of the request (so a fast double-click can't
// submit it twice) and resets the form only once Turbo confirms the
// submission actually succeeded — a validation failure or network error
// leaves the user's typed input in place instead of silently discarding it.
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
    this.element.requestSubmit()
  }
}