import { Controller } from "@hotwired/stimulus"
import { parseListMarker, currentLine, renumberFollowingLines } from "../lib/list_marker"

// Continues Markdown list markers on Enter, removing an empty marker
// instead of continuing it forever. Also lets Tab/Shift+Tab indent a
// list line. Deliberately small, not a step towards CodeMirror.

export default class extends Controller {
  connect() {
    // The marker text this controller's last continuation inserted, when
    // the caret line is still that pristine empty item. Enter exits the
    // list only while armed; any real typing disarms (see keydown).
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
    } else if (event.key?.length === 1 || event.key === "Backspace" || event.key === "Delete") {
      // Real typing ends the pristine continued marker (B5) — Enter
      // must continue from here, not exit. Other keys leave it armed.
      this.armedEmptyMarker = null
    }
  }

  handleEnter(event) {
    if (event.shiftKey || event.ctrlKey || event.metaKey || event.altKey) return

    const textarea = event.target
    const { selectionStart, selectionEnd, value } = textarea
    // A real selection (not just a blinking caret) being replaced by
    // Enter isn't "continue the list at this point" in any well-defined
    // sense — leave it to the browser's normal behavior.
    if (selectionStart !== selectionEnd) return

    const { lineStart, lineEnd, line } = currentLine(value, selectionStart)
    const marker = parseListMarker(line)
    if (!marker) return

    event.preventDefault()

    if (marker.rest.trim() === "") {
      // Empty marker exits only when this controller just inserted it
      // (armed below) — a freshly typed "* " + Enter continues (B5).
      if (this.armedEmptyMarker !== null) {
        textarea.setSelectionRange(lineStart, lineEnd)
        document.execCommand("insertText", false, "")
        // Pin the caret: engines may leave it before the newline.
        textarea.setSelectionRange(lineStart, lineStart)
        this.armedEmptyMarker = null
        return
      }
    }

    // execCommand preserves the undo stack; ordered continuations
    // renumber followers in the same step with the caret pinned.
    const renumbered = marker.ordered
      ? renumberFollowingLines(value, lineEnd, marker.ordered.indent, marker.ordered.number + 2)
      : null
    if (renumbered) {
      const tail = value.slice(selectionStart, lineEnd)
      textarea.setSelectionRange(selectionStart, renumbered.end)
      document.execCommand("insertText", false, `\n${marker.continued}${tail}${renumbered.text}`)
      const caret = selectionStart + 1 + marker.continued.length
      textarea.setSelectionRange(caret, caret)
    } else {
      document.execCommand("insertText", false, `\n${marker.continued}`)
    }
    this.armedEmptyMarker = marker.continued
  }

  handleTab(event) {
    const textarea = event.target
    const { selectionStart, selectionEnd, value } = textarea
    const { lineStart, line } = currentLine(value, selectionStart)

    // Tab is only ever special-cased on a list line; anywhere else it
    // keeps its normal browser meaning (move focus).
    if (!parseListMarker(line)) return

    event.preventDefault()

    if (event.shiftKey) {
      const leading = line.match(/^(\t|  )/)
      if (!leading) return

      const removed = leading[0].length
      textarea.setSelectionRange(lineStart, lineStart + removed)
      document.execCommand("insertText", false, "")
      textarea.setSelectionRange(
        Math.max(lineStart, selectionStart - removed),
        Math.max(lineStart, selectionEnd - removed)
      )
    } else {
      textarea.setSelectionRange(lineStart, lineStart)
      document.execCommand("insertText", false, "  ")
      textarea.setSelectionRange(selectionStart + 2, selectionEnd + 2)
    }
  }
}
