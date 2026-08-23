import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// The Ctrl+P / Cmd+P command palette. The initial list needs no fetch:
// HomeController#index already renders recently-viewed notes into the
// results turbo-frame, so open() only shows the modal and focuses the input.
export default class extends Controller {
  static targets = ["input", "item"]
  static values = { url: String }

  connect() {
    this.modal = bootstrap.Modal.getOrCreateInstance(this.element)
    this.searchTimeout = null

    // Window-scoped since the point is opening the palette from anywhere.
    // preventDefault() on Ctrl/Cmd+P hijacks Print, the same deliberate
    // trade VS Code and similar editors make.
    this.globalKeydownHandler = this.globalKeydown.bind(this)
    window.addEventListener("keydown", this.globalKeydownHandler)
  }

  disconnect() {
    window.removeEventListener("keydown", this.globalKeydownHandler)
  }

  globalKeydown(event) {
    if (event.isComposing) return
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "p") {
      event.preventDefault()
      this.open()
    }
  }

  open() {
    // Calling inputTarget.focus() immediately after show() races
    // Bootstrap's own focus handling and loses. shown.bs.modal fires
    // after that's done, so focusing there wins for real.
    this.element.addEventListener("shown.bs.modal", () => {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }, { once: true })

    this.modal.show()
  }

  // Debounced, and lets Turbo do the fetch by setting the results frame's
  // src — no manual fetch(), no client-side fuzzy-match library.
  search() {
    clearTimeout(this.searchTimeout)

    const query = this.inputTarget.value
    this.searchTimeout = setTimeout(() => {
      const frame = this.element.querySelector("turbo-frame#palette_results")
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)
      frame.src = url.toString()
    }, 150)
  }

  keydown(event) {
    if (event.isComposing) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.move(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.move(-1)
        break
      case "Enter":
        event.preventDefault()
        this.visitSelected()
        break
      case "Escape":
        this.modal.hide()
        break
    }
  }

  select(event) {
    this.visit(event.currentTarget.dataset.url)
  }

  visitSelected() {
    const selected = this.itemTargets.find(item => item.classList.contains("palette-result-selected")) || this.itemTargets[0]
    if (!selected) return

    this.visit(selected.dataset.url)
  }

  visit(url) {
    if (!url) return

    this.modal.hide()
    window.Turbo.visit(url)
  }

  move(delta) {
    const items = this.itemTargets
    if (items.length === 0) return

    let index = items.findIndex(item => item.classList.contains("palette-result-selected"))
    if (index === -1) index = 0

    items[index].classList.remove("palette-result-selected")
    index = (index + delta + items.length) % items.length
    items[index].classList.add("palette-result-selected")
    items[index].scrollIntoView({ block: "nearest" })
  }
}
