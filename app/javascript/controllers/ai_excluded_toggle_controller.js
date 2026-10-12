import { Controller } from "@hotwired/stimulus"
import { adoptNoteVersion } from "./autosave_controller"

// Persists ai_excluded like any other note attribute, through the same
// PATCH path NotesController#update already uses — sending only this one
// field so it can't clobber a concurrent body edit (lock_version).
export default class extends Controller {
  static values = { noteId: Number }

  toggle(event) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    const noteUrl = `/notes/${this.noteIdValue}`
    fetch(noteUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
      },
      body: JSON.stringify({ note: { ai_excluded: event.target.checked } }),
    }).then((response) => {
      if (response.ok) adoptNoteVersion(noteUrl, response.headers.get("X-Note-Lock-Version"))
    }).catch((error) => console.error("Failed to save ai_excluded", error))
  }
}
