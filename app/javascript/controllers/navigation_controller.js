import { Controller } from "@hotwired/stimulus"
import { rememberablePath } from "../lib/last_path.js"

// Restores the last visited notebook/note on reload, via localStorage.
// Scoped to a bare "/" with no query string, since checking path alone
// would clobber in-flight editor navigation.
export default class extends Controller {
  connect() {
    if (window.location.pathname === "/" && window.location.search === "") {
      const last = localStorage.getItem("lastPath")
      const cleaned = last ? rememberablePath(last, window.location.origin) : null

      if (cleaned) {
        localStorage.setItem("lastPath", cleaned)
      } else {
        localStorage.removeItem("lastPath")
      }

      if (cleaned && cleaned !== window.location.href) {
        // Use Turbo to navigate without full reload.
        import("@hotwired/turbo-rails").then(({ Turbo }) => {
          Turbo.visit(cleaned)
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
      const cleaned = rememberablePath(link.href, window.location.origin)
      if (cleaned) localStorage.setItem("lastPath", cleaned)
    }
  }
}
