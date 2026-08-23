import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

const OPEN_FLAG_KEY = "sidebarOpen"

export default class extends Controller {
  connect() {
    this.offcanvas = new bootstrap.Offcanvas(this.element)

    // A Turbo Drive visit tears down this element and loses the
    // client-managed open state. Re-open it if it was open before,
    // below the offcanvas breakpoint only — desktop's sidebar is fixed.
    if (sessionStorage.getItem(OPEN_FLAG_KEY) === "true" && this.belowOffcanvasBreakpoint()) {
      this.offcanvas.show()
    }

    this.element.addEventListener("shown.bs.offcanvas", () => sessionStorage.setItem(OPEN_FLAG_KEY, "true"))
    this.element.addEventListener("hidden.bs.offcanvas", () => sessionStorage.setItem(OPEN_FLAG_KEY, "false"))
  }

  // Called when a note/file link is clicked — the one case that should
  // actually close the menu, since selecting a file is a terminal action.
  close() {
    this.offcanvas.hide()
  }

  belowOffcanvasBreakpoint() {
    // Keep in sync with the "offcanvas-lg" class on the element in
    // home/index.html.erb — Bootstrap's lg breakpoint is 992px.
    return window.matchMedia("(max-width: 991.98px)").matches
  }
}
