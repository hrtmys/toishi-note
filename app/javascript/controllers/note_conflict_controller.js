import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"
import { noteSaveQueue } from "./autosave_controller"

// Owns the "changed on another device" banner, shown on a 409 (see
// autosave_controller.js's note:conflict event). Never auto-resolves —
// a reload would silently overwrite in-progress typing.
export default class extends Controller {
  static targets = [ "banner", "keepMineButton" ]
  // Server-rendered (Rails t(), not the js: subtree) so it stays alongside
  // notes.conflict.reload/keep_mine — see notes/_title_input or wherever
  // this value is set in the view. Same pattern as prompt-form's
  // data-prompt-message.
  static values = { reloadConfirm: String }

  connect() {
    // Bound once so disconnect() can remove the exact same reference —
    // an inline arrow function passed directly to addEventListener can
    // never be removed later (see the navigation_controller.js lesson).
    this.showBound = this.show.bind(this)
    this.element.addEventListener("note:conflict", this.showBound)
    this.warnBeforeUnload = (event) => {
      event.preventDefault()
      event.returnValue = ""
    }
  }

  disconnect() {
    this.element.removeEventListener("note:conflict", this.showBound)
    this.stopWarning()
  }

  show() {
    this.bannerTarget.classList.remove("d-none")
    // Held edits exist only in this tab until the user decides; closing
    // or reloading it now would lose them without a word.
    const queue = this.queue()
    if (queue?.held && queue.hasUnsaved) window.addEventListener("beforeunload", this.warnBeforeUnload)
  }

  stopWarning() {
    window.removeEventListener("beforeunload", this.warnBeforeUnload)
  }

  queue() {
    return noteSaveQueue(this.element)
  }

  // Discards whatever's in progress and shows the server's current
  // state. Confirmed first: this throws real unsaved edits away.
  reload() {
    if (!window.confirm(this.reloadConfirmValue)) return

    this.queue()?.discard()
    this.stopWarning()
    window.location.reload()
  }

  // Resubmits every autosave field's current value over the other
  // device's version. The banner stays up (button disabled) until every
  // resubmission has landed; a failure keeps it open with a toast.
  keepMine() {
    const queue = this.queue()
    if (!queue) return
    if (this.hasKeepMineButtonTarget) this.keepMineButtonTarget.disabled = true

    const fields = Array.from(this.element.querySelectorAll("[data-controller~='autosave'][name]"))
    const saves = fields.map((field) => queue.request(field.getAttribute("name").match(/\[(.*)\]/)[1], field.value))
    queue.keepMine()
    this.stopWarning()

    Promise.all(saves)
      .then((outcomes) => {
        this.element.dataset.noteLockVersion = queue.version
        if (outcomes.every((outcome) => outcome === "saved")) {
          this.bannerTarget.classList.add("d-none")
        } else if (outcomes.includes("failed")) {
          window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("autosave.save_failed") } }))
        }
      })
      .finally(() => {
        if (this.hasKeepMineButtonTarget) this.keepMineButtonTarget.disabled = false
      })
  }
}
