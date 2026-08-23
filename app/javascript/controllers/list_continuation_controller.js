import { Controller } from "@hotwired/stimulus"

// Continues Markdown list markers on Enter, removing an empty marker
// instead of continuing it forever. Also lets Tab/Shift+Tab indent a
// list line. Deliberately small, not a step towards CodeMirror.

// Recognizes five marker shapes: "-", "*", "1.", "- [ ]" (task list), and
// ">". Task-list is checked first since it's a superset of bare bullet.
function parseListMarker(line) {
  let m

  m = line.match(/^(\s*)([-*])(\s+)\[([ xX])\](\s*)/)
  if (m) {
    return {
      full: m[0],
      rest: line.slice(m[0].length),
      // A continued task starts unchecked, regardless of whether the
      // item it followed was checked — carrying a checkmark forward
      // onto a brand new, not-yet-done item would be actively wrong.
      continued: `${m[1]}${m[2]}${m[3]}[ ]${m[5]}`
    }
  }

  m = line.match(/^(\s*)([-*])(\s+)/)
  if (m) {
    return { full: m[0], rest: line.slice(m[0].length), continued: m[0] }
  }

  m = line.match(/^(\s*)(\d+)([.)])(\s+)/)
  if (m) {
    const nextNumber = parseInt(m[2], 10) + 1
    return {
      full: m[0],
      rest: line.slice(m[0].length),
      continued: `${m[1]}${nextNumber}${m[3]}${m[4]}`
    }
  }

  m = line.match(/^(\s*)(>)(\s*)/)
  if (m) {
    return { full: m[0], rest: line.slice(m[0].length), continued: m[0] }
  }

  return null
}

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
    if (event.shiftKey || event.ctrlKey || event.metaKey || event.altKey) return

    const textarea = event.target
    const { selectionStart, selectionEnd, value } = textarea
    // A real selection (not just a blinking caret) being replaced by
    // Enter isn't "continue the list at this point" in any well-defined
    // sense — leave it to the browser's normal behavior.
    if (selectionStart !== selectionEnd) return

    const { lineStart, lineEnd, line } = this.currentLine(value, selectionStart)
    const marker = parseListMarker(line)
    if (!marker) return

    event.preventDefault()

    if (marker.rest.trim() === "") {
      // Nothing after the marker: remove it and drop out of the list,
      // rather than inserting yet another empty item.
      textarea.setSelectionRange(lineStart, lineEnd)
      document.execCommand("insertText", false, "")
      return
    }

    // execCommand("insertText") — not textarea.value = ... — is load-
    // bearing: assigning .value wipes the browser's undo stack. execCommand
    // also leaves the caret right after the inserted marker.
    document.execCommand("insertText", false, `\n${marker.continued}`)
  }

  handleTab(event) {
    const textarea = event.target
    const { selectionStart, selectionEnd, value } = textarea
    const { lineStart, line } = this.currentLine(value, selectionStart)

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

  currentLine(value, caretPosition) {
    const lineStart = value.lastIndexOf("\n", caretPosition - 1) + 1
    const nextNewline = value.indexOf("\n", caretPosition)
    const lineEnd = nextNewline === -1 ? value.length : nextNewline
    return { lineStart, lineEnd, line: value.slice(lineStart, lineEnd) }
  }
}
