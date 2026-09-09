import { Controller } from "@hotwired/stimulus"
import { applyTextTransforms } from "../lib/text_format"

export default class extends Controller {
  static targets = ["option", "modal"]

  connect() {
    // Close modal when clicking outside
    this.outsideClickHandler = this.closeIfOpen.bind(this)
    document.addEventListener('click', this.outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener('click', this.outsideClickHandler)
  }

  toggleModal(event) {
    event.stopPropagation()
    this.modalTarget.classList.toggle('d-none')
  }

  closeIfOpen(event) {
    // Do nothing if the click originated inside this controller (button or modal)
    if (this.element.contains(event.target)) return
    if (!this.modalTarget.classList.contains('d-none')) {
      this.modalTarget.classList.add('d-none')
    }
  }

  applyFormatting() {
    // Find the textarea inside the editor controller (same element hierarchy)
    const textarea = this.element.closest("[data-controller='editor']").querySelector("textarea[data-editor-target='textarea']")
    if (!textarea) return

    const before = textarea.value
    const checkedValues = this.optionTargets.filter(opt => opt.checked).map(opt => opt.value)

    const text = applyTextTransforms(before, checkedValues)

    textarea.value = text
    // Trigger input event so preview updates
    textarea.dispatchEvent(new Event('input'))

    // Hands the exact before/after off to the Compare tab so the change
    // can be inspected. Dispatched via `this.dispatch`, not a direct
    // controller reference, since the Compare pane is a DOM sibling.
    this.dispatch('formatted', { detail: { before, after: text }, bubbles: true })

    // Hide the custom modal after applying formatting
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('d-none')
    }
  }
}
