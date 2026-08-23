import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  reset() {
    this.element.reset()
  }

  // Submits the form on Ctrl+Enter (Cmd+Enter on Mac).
  submit(event) {
    event.preventDefault()
    this.element.requestSubmit()
  }
}