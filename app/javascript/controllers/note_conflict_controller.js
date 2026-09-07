import { Controller } from "@hotwired/stimulus"

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
  }

  disconnect() {
    this.element.removeEventListener("note:conflict", this.showBound)
  }

  show() {
    this.bannerTarget.classList.remove("d-none")
  }

  // Discards whatever's in progress and shows the server's current
  // state — the safe default when the user doesn't know or care what
  // changed on the other device. Confirmed first: this is the one action
  // here that throws real unsaved edits away.
  reload() {
    if (!window.confirm(this.reloadConfirmValue)) return

    window.location.reload()
  }

  // Resubmits every autosave field's current value. The 409 response
  // already refreshed data-note-lock-version, so this retry uses the
  // version the server actually has now.
  //
  // The banner used to hide immediately, before any of those resubmits
  // had actually landed — if one then failed, the user was left with no
  // banner and no error, just silence. Now it stays up (button disabled,
  // as an in-progress cue) until every autosave field's resubmission has
  // actually resolved, and only hides once they've all succeeded; a
  // failure keeps the banner open and raises the normal save-failed toast
  // (autosave_controller.js already does that on its own).
  keepMine() {
    if (this.hasKeepMineButtonTarget) this.keepMineButtonTarget.disabled = true

    const fields = Array.from(this.element.querySelectorAll("[data-controller~='autosave']"))

    Promise.all(fields.map((field) => this.resubmit(field)))
      .then((results) => {
        if (results.every(Boolean)) {
          this.bannerTarget.classList.add("d-none")
        }
      })
      .finally(() => {
        if (this.hasKeepMineButtonTarget) this.keepMineButtonTarget.disabled = false
      })
  }

  // Dispatches the same "input" event autosave already listens for, then
  // waits for that same field's own "autosave:settled" (see
  // autosave_controller.js) to know whether this particular resubmit
  // actually succeeded — scoped to the field itself so one field's
  // failure can't be mistaken for another's on a note with more than one
  // autosaved field (title + content).
  resubmit(field) {
    return new Promise((resolve) => {
      const onSettled = (event) => {
        field.removeEventListener("autosave:settled", onSettled)
        resolve(!!event.detail?.ok)
      }

      field.addEventListener("autosave:settled", onSettled)
      field.dispatchEvent(new Event("input", { bubbles: true }))
    })
  }
}
