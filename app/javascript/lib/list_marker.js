// List-marker parsing shared with the list continuation UI.
// Unit-tested; the controller owns key handling on top of these.

// Recognizes five marker shapes: "-", "*", "1.", "- [ ]" (task list),
// and ">". Task-list is checked first since it's a superset of bare bullet.
export function parseListMarker(line) {
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
      continued: `${m[1]}${nextNumber}${m[3]}${m[4]}`,
      // The renumber step needs these back to fix up the lines below a
      // continued item; bullets/task items/quote never renumber.
      ordered: { indent: m[1], number: parseInt(m[2], 10), delimiter: m[3] }
    }
  }

  m = line.match(/^(\s*)(>)(\s*)/)
  if (m) {
    return { full: m[0], rest: line.slice(m[0].length), continued: m[0] }
  }

  return null
}

export function currentLine(value, caretPosition) {
  const lineStart = value.lastIndexOf("\n", caretPosition - 1) + 1
  const nextNewline = value.indexOf("\n", caretPosition)
  const lineEnd = nextNewline === -1 ? value.length : nextNewline
  return { lineStart, lineEnd, line: value.slice(lineStart, lineEnd) }
}

// Renumbers consecutive same-indent ordered lines below lineEnd so a
// continued item keeps the sequence. Returns null when nothing follows.
export function renumberFollowingLines(value, lineEnd, indent, firstNumber) {
  if (value[lineEnd] !== "\n") return null

  let pos = lineEnd + 1
  let number = firstNumber
  let text = ""
  let end = lineEnd

  for (;;) {
    const nextNewline = value.indexOf("\n", pos)
    const followerEnd = nextNewline === -1 ? value.length : nextNewline
    const follower = value.slice(pos, followerEnd)
    const m = follower.match(/^(\s*)(\d+)([.)])(\s+)(.*)$/)
    if (!m || m[1] !== indent) break

    text += `\n${indent}${number}${m[3]}${m[4]}${m[5]}`
    end = followerEnd
    number += 1
    if (nextNewline === -1) break
    pos = followerEnd + 1
  }

  if (end === lineEnd) return null
  return { end, text }
}

// Enter on a list line: continue the marker, or exit when the line is the
// empty marker this continuation just inserted (armedMarker). null leaves
// Enter to the browser.
export function enterAction({ value, selectionStart, selectionEnd, armedMarker, isComposing, shiftKey, ctrlKey, metaKey, altKey }) {
  if (isComposing || shiftKey || ctrlKey || metaKey || altKey) return null
  // Replacing a real selection isn't "continue the list here" in any
  // well-defined sense.
  if (selectionStart !== selectionEnd) return null

  const { lineStart, lineEnd, line } = currentLine(value, selectionStart)
  const marker = parseListMarker(line)
  if (!marker) return null

  // A freshly typed "* " + Enter continues; only an armed one exits.
  if (marker.rest.trim() === "" && armedMarker !== null) {
    return {
      edit: { start: lineStart, end: lineEnd, text: "", selectionStart: lineStart, selectionEnd: lineStart },
      armedMarker: null
    }
  }

  const caret = selectionStart + 1 + marker.continued.length
  const renumbered = marker.ordered
    ? renumberFollowingLines(value, lineEnd, marker.ordered.indent, marker.ordered.number + 2)
    : null
  const edit = renumbered
    ? {
        start: selectionStart,
        end: renumbered.end,
        text: `\n${marker.continued}${value.slice(selectionStart, lineEnd)}${renumbered.text}`,
        selectionStart: caret,
        selectionEnd: caret
      }
    : { start: selectionStart, end: selectionEnd, text: `\n${marker.continued}`, selectionStart: caret, selectionEnd: caret }
  return { edit, armedMarker: marker.continued }
}

// Tab/Shift+Tab on a list line. null leaves Tab to the browser (focus
// moves); { edit: null } means swallow the key without editing.
export function tabAction({ value, selectionStart, selectionEnd, shiftKey, isComposing }) {
  if (isComposing) return null
  const { lineStart, line } = currentLine(value, selectionStart)
  if (!parseListMarker(line)) return null

  if (!shiftKey) {
    return { edit: { start: lineStart, end: lineStart, text: "  ", selectionStart: selectionStart + 2, selectionEnd: selectionEnd + 2 } }
  }

  const leading = line.match(/^(\t|  )/)
  if (!leading) return { edit: null }
  const removed = leading[0].length
  return {
    edit: {
      start: lineStart,
      end: lineStart + removed,
      text: "",
      selectionStart: Math.max(lineStart, selectionStart - removed),
      selectionEnd: Math.max(lineStart, selectionEnd - removed)
    }
  }
}

// Real typing ends the pristine continued marker, so Enter continues
// from there instead of exiting. Navigation keys leave it armed.
export function disarmsContinuation(key) {
  return key?.length === 1 || key === "Backspace" || key === "Delete"
}
