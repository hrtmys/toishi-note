import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"
import { saveOutcome } from "../lib/autosave"
import { SaveQueue } from "../lib/save_queue"

// Keyed by the note wrapper element, so a queue (and its hold after a
// conflict) outlives any one controller's connect/disconnect.
const saveQueues = new WeakMap()

export function noteSaveQueue(wrapper) {
  return saveQueues.get(wrapper)
}

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
      const wrapper = this.lockVersionElement()
      const queue = this.queueFor(wrapper)

      queue.request(key, this.element.value).then((outcome) => {
        if (wrapper) wrapper.dataset.noteLockVersion = queue.version

        if (outcome === "conflict") {
          // Another device/tab saved first. Never silently resolve by
          // retrying; note_conflict_controller.js shows the user a real
          // choice, and the queue holds this note's saves until then.
          this.element.dispatchEvent(new CustomEvent("note:conflict", { bubbles: true }))
        } else if (outcome === "failed") {
          this.notifySaveFailed()
        }
        this.notifySettled(outcome === "saved")
      })
    }, 500)
  }

  // Title and content share one queue (and one lock_version) on their
  // common note wrapper, so neither ever sends a version the other's
  // in-flight save is about to replace.
  queueFor(wrapper) {
    const owner = wrapper || this.element
    let queue = saveQueues.get(owner)
    if (!queue) {
      queue = new SaveQueue({ version: wrapper?.dataset.noteLockVersion ?? 0, send: (save) => this.send(save) })
      saveQueues.set(owner, queue)
    }
    return queue
  }

  async send({ field, value, version }) {
    const payload = { note: { [field]: value } }
    if (this.lockVersionElement()) payload.note.lock_version = version

    let response
    try {
      response = await fetch(this.urlValue, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify(payload)
      })
    } catch (error) {
      console.error("Failed to autosave", error)
      throw error
    }

    const header = response.headers.get("X-Note-Lock-Version")
    const result = { status: response.status, version: header === null ? null : Number(header) }

    // Only a 2xx body is a turbo stream; a 422/500 page rendered as one
    // would throw an obscure JS error instead of the save-failed toast.
    // A 2xx with an empty body (`head :ok`) is still a landed save.
    if (saveOutcome(response.status) === "saved") {
      const html = await response.text()
      if (html) window.Turbo.renderStreamMessage(html)
    }
    return result
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
