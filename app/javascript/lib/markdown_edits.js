import { currentLine } from "./list_marker.js"

// Editor shortcut decisions as pure functions. An Edit means: select
// [start, end), insert text, then set the selection; performEdit applies
// it through execCommand so Ctrl+Z keeps working.

export function shortcutCommand(event) {
  // Mid-composition keydowns (including the Enter confirming a
  // conversion) must never trigger a shortcut.
  if (event.isComposing) return null
  if ((!event.ctrlKey && !event.metaKey) || event.altKey) return null

  const key = event.key.toLowerCase()
  if (key === "k") return event.shiftKey ? "deleteLine" : "link"
  if (event.shiftKey) return null
  if (key === "b") return "bold"
  if (key === "i") return "italic"
  return null
}

export function wrapEdit(value, selStart, selEnd, fence) {
  const selected = value.slice(selStart, selEnd)
  // No selection: park the caret between the fences so the user types
  // the emphasized text directly.
  const caret = selStart === selEnd ? selStart + fence.length : selEnd + fence.length * 2
  return { start: selStart, end: selEnd, text: `${fence}${selected}${fence}`, selectionStart: caret, selectionEnd: caret }
}

export function linkEdit(value, selStart, selEnd) {
  if (selStart === selEnd) {
    // Select the text placeholder, the part the user most likely edits first.
    return { start: selStart, end: selEnd, text: "[text](url)", selectionStart: selStart + 1, selectionEnd: selStart + 5 }
  }
  const selected = value.slice(selStart, selEnd)
  const urlStart = selStart + selected.length + 3
  return { start: selStart, end: selEnd, text: `[${selected}](url)`, selectionStart: urlStart, selectionEnd: urlStart + 3 }
}

export function deleteLineEdit(value, selStart, selEnd) {
  const { lineStart } = currentLine(value, selStart)
  const { lineEnd } = currentLine(value, selEnd)

  // Swallow one adjacent newline so no blank line is left behind —
  // the trailing one, or the leading one when on the last line.
  let start = lineStart
  let end = lineEnd
  if (value[end] === "\n") {
    end += 1
  } else if (start > 0) {
    start -= 1
  }
  return { start, end, text: "", selectionStart: start, selectionEnd: start }
}

export function urlPasteEdit(value, selStart, selEnd, pastedText, hasImage) {
  if (selStart === selEnd || hasImage) return null
  const url = pastedText?.trim()
  if (!url || !/^https?:\/\/\S+$/i.test(url)) return null

  const text = `[${value.slice(selStart, selEnd)}](${url})`
  const caret = selStart + text.length
  return { start: selStart, end: selEnd, text, selectionStart: caret, selectionEnd: caret }
}

export function applyEdit(value, edit) {
  return value.slice(0, edit.start) + edit.text + value.slice(edit.end)
}

export function performEdit(textarea, edit) {
  textarea.setSelectionRange(edit.start, edit.end)
  document.execCommand("insertText", false, edit.text)
  textarea.setSelectionRange(edit.selectionStart, edit.selectionEnd)
}
