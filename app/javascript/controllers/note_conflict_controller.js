import { Controller } from "@hotwired/stimulus"

// Owns the "changed on another device" banner, shown on a 409 (see
// autosave_controller.js's note:conflict event). Never auto-resolves —
// a reload would silently overwrite in-progress typing.
export default class extends Controller {
  static targets = [ "banner" ]

  connect() {
    // Bound once so disconnect() can remove the exact same reference —
    // an inline arrow function passed directly to addEventListener can
    // never be removed later (see the navigation_controller.js lesson).
    this.showBound = this.show.bind(this)
    this.element.addEventListener("note:conflict", this.showBound)
  }

  disconnect() {
    this.element.removeEventListener("note:conflict", this.showBound)
  }

  show() {
    this.bannerTarget.classList.remove("d-none")
  }

  // Discards whatever's in progress and shows the server's current
  // state — the safe default when the user doesn't know or care what
  // changed on the other device.
  reload() {
    window.location.reload()
  }

  // Resubmits every autosave field's current value. The 409 response
  // already refreshed data-note-lock-version, so this retry uses the
  // version the server actually has now.
  keepMine() {
    this.bannerTarget.classList.add("d-none")

    this.element.querySelectorAll("[data-controller~='autosave']").forEach((field) => {
      field.dispatchEvent(new Event("input", { bubbles: true }))
    })
  }
}
