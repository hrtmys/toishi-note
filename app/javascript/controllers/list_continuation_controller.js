import { Controller } from "@hotwired/stimulus"
import { disarmsContinuation, enterAction, tabAction } from "../lib/list_marker"
import { performEdit } from "../lib/markdown_edits"

// Continues Markdown list markers on Enter, removing an empty marker
// instead of continuing it forever. Also lets Tab/Shift+Tab indent a
// list line. Deliberately small, not a step towards CodeMirror.

export default class extends Controller {
  connect() {
    // The marker text this controller's last continuation inserted, while
    // the caret line is still that pristine empty item.
    this.armedEmptyMarker = null
  }

  keydown(event) {
    // Japanese IME composition sends its own Enter/Tab before either key
    // means anything to us — bail out completely to avoid a stray marker.
    if (event.isComposing) return

    if (event.key === "Enter") {
      this.handleEnter(event)
    } else if (event.key === "Tab") {
      this.handleTab(event)
    } else if (disarmsContinuation(event.key)) {
      this.armedEmptyMarker = null
    }
  }

  handleEnter(event) {
    const textarea = event.target
    const action = enterAction({
      value: textarea.value,
      selectionStart: textarea.selectionStart,
      selectionEnd: textarea.selectionEnd,
      armedMarker: this.armedEmptyMarker,
      isComposing: event.isComposing,
      shiftKey: event.shiftKey,
      ctrlKey: event.ctrlKey,
      metaKey: event.metaKey,
      altKey: event.altKey
    })
    if (!action) return

    event.preventDefault()
    performEdit(textarea, action.edit)
    this.armedEmptyMarker = action.armedMarker
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
