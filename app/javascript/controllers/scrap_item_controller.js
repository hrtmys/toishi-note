import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

// Long scrap content collapses by default — a card-style list of endless
// full-height fragments is a lot less legible than one that only expands
// on request. See "Scrap improvements" in ux-roadmap.md.old.
export default class extends Controller {
  static targets = [ "content", "toggle" ]
  static classes = [ "collapsed" ]
  static values = { threshold: { type: Number, default: 160 }, url: String }

  connect() {
    // The content target also carries the "markdown" controller, which
    // renders HTML in its own connect() — deferring to the next frame
    // guarantees that's already happened before we measure height.
    requestAnimationFrame(() => {
      // Measured before the collapsing class exists, so this reflects the
      // content's natural (unconstrained) height.
      if (this.contentTarget.scrollHeight > this.thresholdValue) {
        this.contentTarget.classList.add(this.collapsedClass)
        this.toggleTarget.classList.remove("d-none")
      }
    })
  }

  toggle() {
    const collapsed = this.contentTarget.classList.toggle(this.collapsedClass)
    this.toggleTarget.textContent = collapsed ? t("scrap.show_more") : t("scrap.show_less")
  }

  // Saves the optional source tag in the background on change — a plain
  // Turbo Drive form submission here would expect a full-page response,
  // which is more than this one small field needs.
  saveSource(event) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
      },
      body: JSON.stringify({ source: event.target.value }),
    }).catch((error) => console.error("Failed to save the scrap source", error))
  }
}
