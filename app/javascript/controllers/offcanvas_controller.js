import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

const OPEN_FLAG_KEY = "sidebarOpen"

export default class extends Controller {
  connect() {
    this.offcanvas = new bootstrap.Offcanvas(this.element)

    // A Turbo visit tears down this element and loses the open state.
    // Restore it below the offcanvas breakpoint only, instantly: an
    // animated show() would replay on an already-open menu.
    if (sessionStorage.getItem(OPEN_FLAG_KEY) === "true" && this.belowOffcanvasBreakpoint()) {
      this.showWithoutAnimation()
    }

    this.element.addEventListener("shown.bs.offcanvas", () => sessionStorage.setItem(OPEN_FLAG_KEY, "true"))
    this.element.addEventListener("hidden.bs.offcanvas", () => sessionStorage.setItem(OPEN_FLAG_KEY, "false"))
  }

  // Called when a note/file link is clicked — the one case that should
  // actually close the menu, since selecting a file is a terminal action.
  close() {
    // Flag synchronously: the Turbo visit can tear the element down
    // before the hide animation's hidden event would record it.
    sessionStorage.setItem(OPEN_FLAG_KEY, "false")
    this.offcanvas.hide()
  }

  // Re-show with the slide transition suppressed (see
  // .offcanvas-instant in _home.scss), avoiding a replayed animation.
  showWithoutAnimation() {
    if (this.element.classList.contains("show")) return
    this.element.classList.add("offcanvas-instant")
    this.element.addEventListener("shown.bs.offcanvas", () => {
      this.element.classList.remove("offcanvas-instant")
    }, { once: true })
    this.offcanvas.show()
  }

  belowOffcanvasBreakpoint() {
    // Keep in sync with the "offcanvas-lg" class on the element in
    // home/index.html.erb — Bootstrap's lg breakpoint is 992px.
    return window.matchMedia("(max-width: 991.98px)").matches
  }
}
