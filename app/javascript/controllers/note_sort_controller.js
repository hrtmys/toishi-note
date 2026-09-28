import { Controller } from "@hotwired/stimulus"
import { DEFAULT_SORT, nextSortState, sortNoteEntries } from "../lib/note_sort"

// Client-side only, on purpose. Nothing here is persisted (pin state
// aside); switching folders or reloading always starts back at the
// default "Updated" sort, matching how the server renders it.
export default class extends Controller {
  static targets = [ "button", "caret", "list", "item" ]

  connect() {
    this.sort = DEFAULT_SORT
    this.applySort()
  }

  setMode(event) {
    this.sort = nextSortState(this.sort, event.currentTarget.dataset.mode)
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
      const active = button.dataset.mode === this.sort.mode
      button.classList.toggle("active", active)

      const caret = this.caretTargets[index]
      caret.className = active ? `bi ${this.sort.direction === "desc" ? "bi-caret-down-fill" : "bi-caret-up-fill"}` : "bi"
    })

    const entries = this.itemTargets.map((item) => ({
      pinned: item.dataset.pinned === "true",
      title: item.dataset.title,
      updatedAt: Number(item.dataset.updatedAt),
      createdAt: Number(item.dataset.createdAt),
      ref: item
    }))
    const items = sortNoteEntries(entries, this.sort).map((entry) => entry.ref)

    items.forEach((item) => this.listTarget.appendChild(item))
  }
}
