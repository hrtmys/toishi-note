import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// Two FAB menu items that seed the Compare modal with the note's content,
// then open it. Hands data across via a dispatched event since
// compare_controller.js is mounted elsewhere.
export default class extends Controller {
  setBefore() { this.stage("before") }
  setAfter() { this.stage("after") }

  stage(side) {
    const textarea = this.element.closest("[data-controller~='editor']").querySelector("textarea[data-editor-target='textarea']")
    if (!textarea) return

    this.dispatch("stage", { detail: { side, value: textarea.value }, bubbles: true })

    bootstrap.Modal.getOrCreateInstance(document.getElementById("compareModal")).show()
  }
}
