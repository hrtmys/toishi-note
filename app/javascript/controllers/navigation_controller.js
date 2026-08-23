import { Controller } from "@hotwired/stimulus"

// Restores the last visited notebook/note on reload, via localStorage.
// Scoped to a bare "/" with no query string, since checking path alone
// would clobber in-flight editor navigation.
export default class extends Controller {
  connect() {
    if (window.location.pathname === "/" && window.location.search === "") {
      const last = localStorage.getItem("lastPath")
      if (last && last !== window.location.href) {
        // Use Turbo to navigate without full reload.
        import("@hotwired/turbo-rails").then(({ Turbo }) => {
          Turbo.visit(last)
        }).catch(() => {})
      }
    }

    // Bound once and stored so disconnect() can remove the exact same
    // reference — a fresh .bind() call each time never matches what was
    // passed to addEventListener, so the old listener never gets removed.
    this._storeLocationHandler = this.storeLocation.bind(this)
    this.element.addEventListener("click", this._storeLocationHandler)
  }

  disconnect() {
    this.element.removeEventListener("click", this._storeLocationHandler)
  }

  storeLocation(event) {
    const link = event.target.closest("a")
    if (link && link.href) {
      try {
        const url = new URL(link.href)
        // Only remember note-editor navigation (root path, note/notebook
        // params) — a click into an admin/auth page shouldn't later
        // "restore" you there on the next root-path visit.
        if (url.origin === window.location.origin && url.pathname === "/") {
          localStorage.setItem("lastPath", url.href)
        }
      } catch (_) {}
    }
  }
}
