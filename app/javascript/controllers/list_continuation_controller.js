import { Controller } from "@hotwired/stimulus"
import { enterAction, tabAction } from "../lib/list_marker"
import { performEdit } from "../lib/markdown_edits"

// Continues Markdown list markers on Enter; Enter on an empty marker exits the list,
// or outdents one level under a parent item. Tab/Shift+Tab indent and outdent list lines.

export default class extends Controller {
  keydown(event) {
    // Japanese IME composition sends its own Enter/Tab before either key
    // means anything to us — bail out completely to avoid a stray marker.
    if (event.isComposing) return

    if (event.key === "Enter") {
      this.handleEnter(event)
    } else if (event.key === "Tab") {
      this.handleTab(event)
    }
  }

  handleEnter(event) {
    const textarea = event.target
    const action = enterAction({
      value: textarea.value,
      selectionStart: textarea.selectionStart,
      selectionEnd: textarea.selectionEnd,
      isComposing: event.isComposing,
      shiftKey: event.shiftKey,
      ctrlKey: event.ctrlKey,
      metaKey: event.metaKey,
      altKey: event.altKey
    })
    if (!action) return

    event.preventDefault()
    performEdit(textarea, action.edit)
  }

  handleTab(event) {
    const textarea = event.target
    const action = tabAction({
      value: textarea.value,
      selectionStart: textarea.selectionStart,
      selectionEnd: textarea.selectionEnd,
      shiftKey: event.shiftKey,
      isComposing: event.isComposing
    })
    if (!action) return

    event.preventDefault()
    if (action.edit) performEdit(textarea, action.edit)
  }
}
