import { Controller } from "@hotwired/stimulus"

// Submits the element's own form as soon as it changes — for a checkbox
// that should persist instantly, with no "Save" button. A Stimulus
// action, not inline onchange="", since CSP's script-src blocks that.
export default class extends Controller {
  submit() {
    this.element.form.requestSubmit()
  }
}
