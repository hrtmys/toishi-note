import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.timeout = null
    // True between IME compositionstart/compositionend. While set, input
    // events carry unconfirmed text — saving it would persist a
    // half-converted fragment (and auto-title from it).
    this.composing = false
  }

  // Paired with compositionend below; both the title input and the content
  // textarea wire these via data-action (see notes/_title_input.html.erb
  // and notes/_md_editor.html.erb).
  compositionstart() {
    this.composing = true
    clearTimeout(this.timeout)
  }

  compositionend() {
    this.composing = false
    this.save()
  }

  save(event) {
    // Input events fired mid-composition (Chrome fires one per keystroke
    // before the conversion is confirmed) must not start the debounce.
    if (this.composing || event?.isComposing) return

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
          this.notifySettled(false)
          return null
        }

        if (!response.ok) {
          // A non-2xx, non-409 response (422, 500, ...) isn't a valid
          // turbo-stream body — rendering it as one would throw an obscure
          // JS error instead of telling the user anything useful.
          this.notifySaveFailed()
          this.notifySettled(false)
          return null
        }

        return response.text()
      })
      .then(html => {
        if (html) {
          window.Turbo.renderStreamMessage(html)
          this.notifySettled(true)
        }
      })
      .catch(error => {
        // Network failure, CORS, etc. — the fetch itself rejected before
        // any response came back.
        console.error("Failed to autosave", error)
        this.notifySaveFailed()
        this.notifySettled(false)
      })
    }, 500)
  }

  notifySaveFailed() {
    window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("autosave.save_failed") } }))
  }

  // Fired after every save attempt resolves, success or failure — the one
  // hook a caller needs to know a particular save actually landed rather
  // than just having been *triggered*. note_conflict_controller.js's
  // "Keep mine" uses this to know when it's actually safe to hide the
  // conflict banner, instead of hiding it the instant the retry starts.
  notifySettled(ok) {
    this.element.dispatchEvent(new CustomEvent("autosave:settled", { bubbles: true, detail: { ok } }))
  }

  lockVersionElement() {
    return this.element.closest("[data-note-lock-version]")
  }
}
