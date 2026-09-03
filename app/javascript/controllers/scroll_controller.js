import { Controller } from "@hotwired/stimulus"

// Keeps a scrollable sidebar list showing the right part of itself after
// a re-render — normally "wherever the active row is," computed fresh
// each connect. A persisted scrollTop is a fallback for no active row.
export default class extends Controller {
  connect() {
    this.restoreOrScrollToActive()

    this._saveHandler = this.save.bind(this)
    this.element.addEventListener("scroll", this._saveHandler)

    // A Turbo Drive visit can re-render this element after it already
    // connected once — turbo:load re-runs the same lookup instead of
    // trusting whatever connect() found.
    if (window.Turbo) {
      this._turboHandler = () => this.restoreOrScrollToActive()
      document.addEventListener("turbo:load", this._turboHandler)
    }
  }

  disconnect() {
    if (this._saveHandler) {
      this.element.removeEventListener("scroll", this._saveHandler)
    }
    if (this._turboHandler) {
      document.removeEventListener("turbo:load", this._turboHandler)
    }
  }

  restoreOrScrollToActive() {
    // The saved scrollTop wins first — every click here is a full page
    // navigation that rebuilds this element from scratch, and snapping
    // straight to the active row on every one of them is what made the
    // list feel like it reset to the top on every click. Restoring the
    // prior position, then nudging the active row into view only if it
    // isn't already visible, keeps browsing position stable while still
    // guaranteeing the current selection is never scrolled out of reach.
    const value = localStorage.getItem(this.storageKey())
    if (value !== null) {
      this.element.scrollTop = parseInt(value, 10)
    }

    // .bg-secondary is the one class every active row (notebook, folder,
    // or note) gets in home/_sidebar.html.erb — a single selector works
    // for all three lists this controller is mounted on.
    const active = this.element.querySelector(".bg-secondary")
    if (active) {
      active.scrollIntoView({ block: "nearest" })
    }
  }

  save() {
    localStorage.setItem(this.storageKey(), this.element.scrollTop)
  }

  storageKey() {
    const id = this.element.dataset.scrollId || this.element.id
    return `scrollPos-${id}`
  }
}
