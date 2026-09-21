import { Controller } from "@hotwired/stimulus"

// Persists ai_excluded like any other note attribute, through the same
// PATCH path NotesController#update already uses — sending only this one
// field so it can't clobber a concurrent body edit (lock_version).
export default class extends Controller {
  static values = { noteId: Number }

  toggle(event) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(`/notes/${this.noteIdValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
      },
      body: JSON.stringify({ note: { ai_excluded: event.target.checked } }),
    }).catch((error) => console.error("Failed to save ai_excluded", error))
  }
}
