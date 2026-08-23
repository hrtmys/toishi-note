import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// A single, app-wide toast (e.g. "Copied.") triggered from anywhere via
// window.dispatchEvent(new CustomEvent("toast:show", { detail: { message } })),
// rather than every feature needing to build its own confirmation UI.
export default class extends Controller {
  static targets = ["toast", "body"]

  connect() {
    this.bsToast = bootstrap.Toast.getOrCreateInstance(this.toastTarget, { delay: 2000 })
  }

  show(event) {
    this.bodyTarget.textContent = event.detail.message
    this.bsToast.show()
  }
}
