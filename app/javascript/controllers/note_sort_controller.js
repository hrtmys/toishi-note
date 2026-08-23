import { Controller } from "@hotwired/stimulus"

// Client-side only, on purpose. Nothing here is persisted (pin state
// aside); switching folders or reloading always starts back at the
// default "Updated" sort, matching how the server renders it.
export default class extends Controller {
  static targets = [ "button", "caret", "list", "item" ]

  connect() {
    this.mode = "updated"
    this.direction = "desc"
    this.applySort()
  }

  setMode(event) {
    const mode = event.currentTarget.dataset.mode

    if (mode === this.mode) {
      this.direction = this.direction === "desc" ? "asc" : "desc"
    } else {
      this.mode = mode
      this.direction = mode === "title" ? "asc" : "desc"
    }

    this.applySort()
  }

  togglePin(event) {
    event.preventDefault()

    const button = event.currentTarget
    const item = button.closest("[data-note-sort-target='item']")
    const pinned = item.dataset.pinned !== "true"

    item.dataset.pinned = pinned
    button.classList.toggle("pin-active", pinned)
    button.querySelector("i").className = pinned ? "bi bi-pin-fill" : "bi bi-pin"
    this.applySort()

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(`/notes/${button.dataset.noteId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
      },
      body: JSON.stringify({ note: { is_pinned: pinned } }),
    }).catch((error) => console.error("Failed to save pin state", error))
  }

  applySort() {
    this.buttonTargets.forEach((button, index) => {
      const active = button.dataset.mode === this.mode
      button.classList.toggle("active", active)

      const caret = this.caretTargets[index]
      caret.className = active ? `bi ${this.direction === "desc" ? "bi-caret-down-fill" : "bi-caret-up-fill"}` : "bi"
    })

    const key = this.mode === "title" ? "title" : `${this.mode}At`
    const factor = this.direction === "asc" ? 1 : -1

    const items = [ ...this.itemTargets ].sort((a, b) => {
      const pinnedA = a.dataset.pinned === "true"
      const pinnedB = b.dataset.pinned === "true"
      if (pinnedA !== pinnedB) return pinnedA ? -1 : 1

      if (this.mode === "title") {
        return factor * a.dataset[key].localeCompare(b.dataset[key])
      }
      return factor * (Number(a.dataset[key]) - Number(b.dataset[key]))
    })

    items.forEach((item) => this.listTarget.appendChild(item))
  }
}
