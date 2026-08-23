import { Controller } from "@hotwired/stimulus"

// Selects an input's full text on click — for a readonly field like an
// admin invite/reset link. A Stimulus action, not inline onclick="",
// since the CSP's script-src has no 'unsafe-inline'.
export default class extends Controller {
  select() {
    this.element.select()
  }
}
