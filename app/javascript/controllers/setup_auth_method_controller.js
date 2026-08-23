import { Controller } from "@hotwired/stimulus"

// Setup offers a password form (default) or a trusted reverse-proxy
// header (only when TRUSTED_HEADER_AUTH_HEADER is set). The latter
// hides the password fields.
export default class extends Controller {
  static targets = ["passwordFields", "teamDescriptionPassword", "teamDescriptionTrustedHeader"]

  toggle(event) {
    const trustedHeader = event.target.value === "trusted_header"

    this.passwordFieldsTarget.classList.toggle("d-none", trustedHeader)
    // `display: none` isn't enough: Chrome blocks submit on a hidden
    // `required` field ("not focusable"). Clearing it is what works.
    this.passwordFieldsTarget.querySelectorAll("input").forEach((input) => {
      input.required = !trustedHeader
    })

    this.teamDescriptionPasswordTarget.classList.toggle("d-none", trustedHeader)
    this.teamDescriptionTrustedHeaderTarget.classList.toggle("d-none", !trustedHeader)
  }
}
