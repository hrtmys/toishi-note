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
    // .bg-secondary is the one class every active row (notebook, folder,
    // or note) gets in home/_sidebar.html.erb — a single selector works
    // for all three lists this controller is mounted on.
    const active = this.element.querySelector(".bg-secondary")
    if (active) {
      active.scrollIntoView({ block: "nearest" })
      return
    }

    const value = localStorage.getItem(this.storageKey())
    if (value !== null) {
      this.element.scrollTop = parseInt(value, 10)
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
