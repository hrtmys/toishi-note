import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  save() {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      const fieldName = this.element.getAttribute("name")
      if (!fieldName) return

      const key = fieldName.match(/\[(.*)\]/)[1]
      const payload = { note: {} }
      payload.note[key] = this.element.value

      // Title and content autosave independently but share one
      // lock_version on their common note wrapper, so editing one then
      // the other doesn't conflict with itself.
      const lockVersionElement = this.lockVersionElement()
      if (lockVersionElement) {
        payload.note.lock_version = lockVersionElement.dataset.noteLockVersion
      }

      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      fetch(this.urlValue, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify(payload)
      })
      .then(response => {
        // Told on every response, success or conflict, so the next save
        // always submits the version the server actually has now.
        const newVersion = response.headers.get("X-Note-Lock-Version")
        if (newVersion !== null && lockVersionElement) {
          lockVersionElement.dataset.noteLockVersion = newVersion
        }

        if (response.status === 409) {
          // Another device/tab saved first. Never silently resolve by
          // retrying; note_conflict_controller.js shows the user a real
          // choice, and this field's pending edit stays as typed.
          this.element.dispatchEvent(new CustomEvent("note:conflict", { bubbles: true }))
          return null
        }

        return response.text()
      })
      .then(html => {
        if (html) {
          window.Turbo.renderStreamMessage(html)
        }
      })
    }, 500)
  }

  lockVersionElement() {
    return this.element.closest("[data-note-lock-version]")
  }
}
