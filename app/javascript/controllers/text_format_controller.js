import { Controller } from "@hotwired/stimulus"

// Utility functions for text transformations
function fullwidthToHalfwidth(text) {
  return text.replace(/[０-９]/g, ch => String.fromCharCode(ch.charCodeAt(0) - 0xFEE0))
}

function removePunctuationSpace(text) {
  // Remove spaces after Japanese punctuation marks
  return text.replace(/([、。])\s+/g, "$1")
}

function removeNumberJpSpace(text) {
  // Remove spaces between numbers and Japanese characters
  return text.replace(/([0-9])\s+([ぁ-んァ-ン一-龯])/g, "$1$2")
}

function collapseNewlines(text) {
  // Replace two or more consecutive newlines with a single newline
  return text.replace(/\n{2,}/g, "\n")
}

function removeBracketed(text) {
  // Remove content inside square brackets, including the brackets
  return text.replace(/\[[^\]]*\]/g, "")
}

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
    let text = before
    const checkedValues = this.optionTargets.filter(opt => opt.checked).map(opt => opt.value)

    // Run in a fixed order so results are deterministic regardless of checkbox
    // DOM order: bracket removal can leave blank lines behind, so newline
    // collapsing must run last to normalize the final result.
    const ORDER = [
      "fullwidth_to_halfwidth",
      "punctuation_space",
      "number_jp_space",
      "remove_brackets",
      "collapse_newlines"
    ]
    const selectedOptions = ORDER.filter(opt => checkedValues.includes(opt))

    selectedOptions.forEach(opt => {
      switch (opt) {
        case "fullwidth_to_halfwidth":
          text = fullwidthToHalfwidth(text)
          break
        case "punctuation_space":
          text = removePunctuationSpace(text)
          break
        case "number_jp_space":
          text = removeNumberJpSpace(text)
          break
        case "collapse_newlines":
          text = collapseNewlines(text)
          break
        case "remove_brackets":
          text = removeBracketed(text)
          break
        default:
          break
      }
    })

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
