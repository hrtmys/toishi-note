import { Controller } from "@hotwired/stimulus"

// Owns the AI-formatting FAB's open/closed state; word-copy and
// text-format (stacked on the same element) handle the actual actions.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.outsideClickHandler = this.closeIfOutside.bind(this)
    document.addEventListener("click", this.outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  toggleMenu(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("d-none")
    // Same pressed-in "active" treatment the Edit/Split/Preview/Diff
    // buttons use — an outline button already knows how to invert its own
    // colors for it, no bespoke styling needed here.
    this.buttonTarget.classList.toggle("active")
  }

  close() {
    this.menuTarget.classList.add("d-none")
    this.buttonTarget.classList.remove("active")
  }

  closeIfOutside(event) {
    if (this.element.contains(event.target)) return
    this.close()
  }
}
