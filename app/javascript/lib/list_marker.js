// List-marker parsing shared with the list continuation UI.
// Unit-tested; the controller owns key handling on top of these.

// Recognizes six marker shapes: "-", "*", "+", "1.", "- [ ]" (task list),
// and ">". Task-list is checked first since it's a superset of bare bullet.
// CommonMark counts only ASCII spaces as a gap, so the full-width and no-break ones map to spaces.
const asciiGap = (text) => text.replace(/[　 ]/g, " ")

export function parseListMarker(line) {
  let m

  m = line.match(/^([ \t]*)([-*+])([ \t　 ]+)\[([ xX])\]([ \t　 ]*)/)
  if (m) {
    return {
      full: m[0],
      rest: line.slice(m[0].length),
      // A continued task starts unchecked, regardless of whether the
      // item it followed was checked — carrying a checkmark forward
      // onto a brand new, not-yet-done item would be actively wrong.
      continued: `${m[1]}${m[2]}${asciiGap(m[3])}[ ]${asciiGap(m[5])}`
    }
  }

  m = line.match(/^([ \t]*)([-*+])([ \t　 ]+)/)
  if (m) {
    return { full: m[0], rest: line.slice(m[0].length), continued: asciiGap(m[0]) }
  }

  m = line.match(/^([ \t]*)(\d+)([.)])([ \t　 ]+)/)
  if (m) {
    const nextNumber = parseInt(m[2], 10) + 1
    return {
      full: m[0],
      rest: line.slice(m[0].length),
      continued: `${m[1]}${nextNumber}${m[3]}${asciiGap(m[4])}`,
      ordered: { indent: m[1], number: parseInt(m[2], 10), delimiter: m[3] }
    }
  }

  m = line.match(/^([ \t]*)(>)([ \t　 ]*)/)
  if (m) {
    return { full: m[0], rest: line.slice(m[0].length), continued: asciiGap(m[0]) }
  }

  return null
}

export function currentLine(value, caretPosition) {
  const lineStart = value.lastIndexOf("\n", caretPosition - 1) + 1
  const nextNewline = value.indexOf("\n", caretPosition)
  const lineEnd = nextNewline === -1 ? value.length : nextNewline
  return { lineStart, lineEnd, line: value.slice(lineStart, lineEnd) }
}

function indentWidth(whitespace) {
  let width = 0
  for (const ch of whitespace) width += ch === "\t" ? 4 : 1
  return width
}

// The nearest shallower non-blank line; null when it is not a list item.
function findParentItem(value, lineStart, width) {
  let end = lineStart - 1
  while (end >= 0) {
    const start = end > 0 ? value.lastIndexOf("\n", end - 1) + 1 : 0
    const line = value.slice(start, end)
    const lineEnd = end
    end = start - 1
    if (line.trim() === "" || indentWidth(line.match(/^[ \t]*/)[0]) >= width) continue

    const marker = parseListMarker(line)
    if (!marker || marker.full.trim().startsWith(">")) return null
    return { lineStart: start, lineEnd, marker }
  }
  return null
}

// Enter on a list line: continue the marker, or exit when the marker is empty.
// null leaves Enter to the browser.
export function enterAction({ value, selectionStart, selectionEnd, isComposing, shiftKey, ctrlKey, metaKey, altKey }) {
  if (isComposing || shiftKey || ctrlKey || metaKey || altKey) return null
  // Replacing a real selection isn't "continue the list here" in any
  // well-defined sense.
  if (selectionStart !== selectionEnd) return null

  const { lineStart, lineEnd, line } = currentLine(value, selectionStart)
  const marker = parseListMarker(line)
  if (!marker) return null

  if (marker.rest.trim() === "") {
    const indent = line.match(/^[ \t]*/)[0]
    const isQuote = marker.full.trim().startsWith(">")
    const width = indentWidth(indent)
    const parent = width > 0 ? findParentItem(value, lineStart, width) : null

    if (parent && !isQuote) {
      const caret = lineStart + parent.marker.continued.length
      return {
        edit: {
          start: lineStart,
          end: lineEnd,
          text: parent.marker.continued,
          selectionStart: caret,
          selectionEnd: caret
        }
      }
    }

    // Without the blank line, text typed after the exit joins the list as a lazy continuation.
    const previous = lineStart > 0 ? value.slice(value.lastIndexOf("\n", lineStart - 2) + 1, lineStart - 1) : ""
    const blank = previous.trim() !== "" ? "\n" : ""
    const text = parent ? blank + indent : blank
    const caret = lineStart + text.length
    return { edit: { start: lineStart, end: lineEnd, text, selectionStart: caret, selectionEnd: caret } }
  }

  const caret = selectionStart + 1 + marker.continued.length
  if (/[\u3000\u00A0]/.test(marker.full)) {
    // The edit covers the whole line so the current line's gap is rewritten in the same undo step.
    const markerEnd = lineStart + marker.full.length
    const lineText = asciiGap(value.slice(lineStart, markerEnd)) + value.slice(markerEnd, lineEnd)
    const split = selectionStart - lineStart
    const edit = {
      start: lineStart,
      end: lineEnd,
      text: `${lineText.slice(0, split)}\n${marker.continued}${lineText.slice(split)}`,
      selectionStart: caret,
      selectionEnd: caret
    }
    return { edit }
  }
  return { edit: { start: selectionStart, end: selectionEnd, text: `\n${marker.continued}`, selectionStart: caret, selectionEnd: caret } }
}

// Items above the line, nearest first. Indented non-list lines are continuation
// text of the item above, so they are skipped rather than ending the list.
function itemsAbove(value, lineStart) {
  const items = []
  let end = lineStart - 1
  while (end >= 0) {
    const start = end > 0 ? value.lastIndexOf("\n", end - 1) + 1 : 0
    const line = value.slice(start, end)
    end = start - 1
    if (line.trim() === "") continue

    const marker = parseListMarker(line)
    if (marker?.full.trim().startsWith(">")) break
    if (!marker) {
      if (indentWidth(line.match(/^[ \t]*/)[0]) === 0) break
      continue
    }
    // CommonMark: five or more spaces after a marker make the content start one space after it.
    const [, lead, bullet, gap] = line.match(/^([ \t]*)([-*+]|\d+[.)])([ \t　 ]+)/)
    const indent = indentWidth(lead)
    const spaces = indentWidth(gap)
    items.push({ indent, child: indent + bullet.length + (spaces >= 5 ? 1 : spaces) })
  }
  return items
}

// True when no item at `indent` precedes a shallower one, i.e. the line opens a new level.
function isFirstAt(items, indent) {
  const nearest = items.find((item) => item.indent <= indent)
  return !nearest || nearest.indent < indent
}

// Tab/Shift+Tab on a list line. null leaves Tab to the browser (focus
// moves); { edit: null } means swallow the key without editing.
export function tabAction({ value, selectionStart, selectionEnd, shiftKey, isComposing }) {
  if (isComposing) return null
  const { lineStart, line } = currentLine(value, selectionStart)
  const marker = parseListMarker(line)
  if (!marker) return null
  if (marker.full.trim().startsWith(">")) return { edit: null }

  const leading = line.match(/^[ \t]*/)[0]
  const current = indentWidth(leading)
  const items = itemsAbove(value, lineStart)
  const levels = items.flatMap((item) => [item.indent, item.child])
  const target = shiftKey
    ? Math.max(0, ...levels.filter((level) => level < current))
    : Math.min(...levels.filter((level) => level > current))
  if (!Number.isFinite(target) || target === current) return { edit: null }

  // CommonMark: a nested list that does not start at 1 cannot interrupt the parent's paragraph.
  const ordered = line.match(/^([ \t]*)(\d+)([.)])/)
  const renumber = ordered && isFirstAt(items, target)
  const prefix = renumber ? ordered[0] : leading
  const text = " ".repeat(target) + (renumber ? `1${ordered[3]}` : "")
  const delta = text.length - prefix.length
  return {
    edit: {
      start: lineStart,
      end: lineStart + prefix.length,
      text,
      selectionStart: Math.max(lineStart, selectionStart + delta),
      selectionEnd: Math.max(lineStart, selectionEnd + delta)
    }
  }
}
