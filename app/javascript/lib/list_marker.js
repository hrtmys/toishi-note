import { fenceStep, insideFence } from "./markdown_source.js"

// List-marker parsing shared with the list continuation UI.
// Unit-tested; the controller owns key handling on top of these.

// A line may start with a ">" quote prefix, then a task, bullet or ordered marker.
// Tasks are checked first since they're a superset of the bare bullet.
// CommonMark counts only ASCII spaces as a gap, so the full-width and no-break ones map to spaces.
const asciiGap = (text) => text.replace(/[\u3000\u00A0]/g, " ")

const QUOTE_PREFIX = /^[ \t]*(?:>[ \t\u3000\u00A0]?)+/
const THEMATIC_BREAK = /^[ \t]*([-*_])([ \t]*\1){2,}[ \t]*$/
const BULLET_TASK = /^([ \t]*)([-*+])([ \t\u3000\u00A0]+)\[([ xX])\]([ \t\u3000\u00A0]+)/
const ORDERED_TASK = /^([ \t]*)(\d+)([.)])([ \t\u3000\u00A0]+)\[([ xX])\]([ \t\u3000\u00A0]+)/
const BULLET = /^([ \t]*)([-*+])([ \t\u3000\u00A0]+)/
const ORDERED = /^([ \t]*)(\d+)([.)])([ \t\u3000\u00A0]+)/

function listMarker(line, quote, matched, continued) {
  const full = quote + matched
  return { full, rest: line.slice(full.length), continued, quote }
}

export function parseListMarker(line) {
  const quote = line.match(QUOTE_PREFIX)?.[0] ?? ""
  const text = line.slice(quote.length)
  if (THEMATIC_BREAK.test(text)) return null
  const quoteGap = asciiGap(quote)

  let m = text.match(BULLET_TASK)
  if (m) {
    // A continued task starts unchecked, regardless of whether the
    // item it followed was checked — carrying a checkmark forward
    // onto a brand new, not-yet-done item would be actively wrong.
    return listMarker(line, quote, m[0], `${quoteGap}${m[1]}${m[2]}${asciiGap(m[3])}[ ]${asciiGap(m[5])}`)
  }

  m = text.match(ORDERED_TASK)
  if (m) {
    const nextNumber = parseInt(m[2], 10) + 1
    return listMarker(line, quote, m[0], `${quoteGap}${m[1]}${nextNumber}${m[3]}${asciiGap(m[4])}[ ]${asciiGap(m[6])}`)
  }

  m = text.match(BULLET)
  if (m) return listMarker(line, quote, m[0], quoteGap + asciiGap(m[0]))

  m = text.match(ORDERED)
  if (m) {
    const nextNumber = parseInt(m[2], 10) + 1
    return listMarker(line, quote, m[0], `${quoteGap}${m[1]}${nextNumber}${m[3]}${asciiGap(m[4])}`)
  }

  if (!quote) return null
  return { full: quote, rest: text, continued: quoteGap, quote }
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

const ATX_HEADING = /^ {0,3}#{1,6}([ \t]|$)/

// A bare quote prefix parses as a marker too.
const isListItem = (line) => {
  const marker = parseListMarker(line)
  return marker !== null && marker.full !== marker.quote
}

// CommonMark: only an ordered item starting at 1 can interrupt a paragraph.
function isParagraphAbove(value, lineStart, quote) {
  if (lineStart === 0) return false
  const prevEnd = lineStart - 1
  const prevStart = prevEnd > 0 ? value.lastIndexOf("\n", prevEnd - 1) + 1 : 0
  const prev = value.slice(prevStart, prevEnd)
  if (prev.trim() === "" || insideFence(value, prevStart)) return false
  const prevQuote = prev.match(QUOTE_PREFIX)?.[0] ?? ""
  if (asciiGap(prevQuote) !== asciiGap(quote)) return false
  const text = prev.slice(prevQuote.length)
  if (text.trim() === "" || isListItem(text) || ATX_HEADING.test(text) || THEMATIC_BREAK.test(text)) return false

  let end = prevStart - 1
  while (end >= 0) {
    const start = end > 0 ? value.lastIndexOf("\n", end - 1) + 1 : 0
    const above = value.slice(start, end)
    if (above.trim() === "") break
    if (isListItem(above)) return false
    end = start - 1
  }
  return true
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
  if (insideFence(value, lineStart)) return null

  const hasRest = marker.rest.trim() !== ""
  const offset = selectionStart - lineStart
  if (hasRest && offset < marker.full.length) {
    if (!marker.quote || offset < marker.quote.length) return null
    const text = `\n${asciiGap(marker.quote)}`
    const caret = selectionStart + text.length
    return { edit: { start: selectionStart, end: selectionStart, text, selectionStart: caret, selectionEnd: caret } }
  }
  const ordered = line.slice(marker.quote.length).match(/^[ \t]*(\d+)[.)]/)
  if (hasRest && ordered && Number(ordered[1]) !== 1 && isParagraphAbove(value, lineStart, marker.quote)) return null

  if (!hasRest) {
    if (marker.quote && marker.quote !== marker.full) {
      const text = asciiGap(marker.quote)
      const caret = lineStart + text.length
      return { edit: { start: lineStart, end: lineEnd, text, selectionStart: caret, selectionEnd: caret } }
    }
    const indent = line.match(/^[ \t]*/)[0]
    const isQuote = marker.quote !== ""
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

// One flag per line up to lineIndex: whether the line sits inside a fence.
function fencedFlags(value, lineIndex) {
  let fence = null
  return value.split("\n", lineIndex + 1).map((line) => {
    const step = fenceStep(fence, line)
    fence = step.fence
    return step.inFence
  })
}

const lineIndexOf = (value, offset) => value.slice(0, offset).split("\n").length - 1

const isItem = (line) => isListItem(line) && !QUOTE_PREFIX.test(line)

const isPlainParagraph = (line) => line.trim() !== ""
  && indentWidth(line.match(/^[ \t]*/)[0]) === 0
  && !QUOTE_PREFIX.test(line)
  && !isListItem(line)
  && !ATX_HEADING.test(line)
  && !THEMATIC_BREAK.test(line)
  && !fenceStep(null, line).inFence
  && !line.startsWith("|")

const isIndentedText = (line) => line.trim() !== ""
  && indentWidth(line.match(/^[ \t]*/)[0]) > 0
  && !QUOTE_PREFIX.test(line)
  && !isListItem(line)

// A lazy run counts as continuation only when it hangs from an item; indented text is part of that item's paragraph.
function continuesItem(above, index, flags) {
  let j = index
  while (j >= 0 && !flags[j] && (isPlainParagraph(above[j]) || isIndentedText(above[j]))) j--
  return j >= 0 && !flags[j] && isItem(above[j])
}

// Tab stops are measured from the marker's column; a gap of 5+ columns starts content one column after the marker.
function childIndent(indent, bullet, gap) {
  const column = indent + bullet.length
  let width = 0
  for (const ch of gap) width += ch === "\t" ? 4 - ((column + width) % 4) : 1
  return column + (width >= 5 ? 1 : width)
}

// Items above the line, nearest first. Continuation text and lazy paragraph lines are skipped rather than
// ending the list; fenced lines are skipped, except a fence at indent 0, which ends it.
function itemsAbove(value, lineStart, flags) {
  const above = lineStart === 0 ? [] : value.slice(0, lineStart - 1).split("\n")
  const items = []
  for (let i = above.length - 1; i >= 0; i--) {
    const line = above[i]
    if (line.trim() === "") continue
    const indent = indentWidth(line.match(/^[ \t]*/)[0])
    if (flags[i]) {
      if (indent === 0) break
      continue
    }

    const marker = parseListMarker(line)
    if (marker?.full.trim().startsWith(">")) break
    if (!marker) {
      if (indent > 0 || continuesItem(above, i, flags)) continue
      break
    }
    const [, bullet, gap] = line.match(/^[ \t]*([-*+]|\d+[.)])([ \t\u3000\u00A0]+)/)
    items.push({ indent, child: childIndent(indent, bullet, gap) })
  }
  return items
}

// True when no item at `indent` precedes a shallower one, i.e. the line opens a new level.
function isFirstAt(items, indent) {
  const nearest = items.find((item) => item.indent <= indent)
  return !nearest || nearest.indent < indent
}

// Leading whitespace that Shift+Tab removes from a non-list line: one tab, else up to two spaces.
function outdentWidth(line) {
  if (line.startsWith("\t")) return 1
  return line.match(/^ {0,2}/)[0].length
}

// The new leading whitespace of a list line, with its renumbered marker; null when its level does not change.
function listChange(items, line, shiftKey) {
  const leading = line.match(/^[ \t]*/)[0]
  const current = indentWidth(leading)
  const levels = items.flatMap((item) => [item.indent, item.child])
  const target = shiftKey
    ? Math.max(0, ...levels.filter((level) => level < current))
    : Math.min(...levels.filter((level) => level > current))
  if (!Number.isFinite(target) || target === current) return null

  // CommonMark: a nested list that does not start at 1 cannot interrupt the parent's paragraph.
  const ordered = line.match(/^([ \t]*)(\d+)([.)])/)
  const renumber = ordered && isFirstAt(items, target)
  return {
    prefix: renumber ? ordered[0] : leading,
    text: " ".repeat(target) + (renumber ? `1${ordered[3]}` : "")
  }
}

// `text` already holds the lines above this one as rewritten.
function rewriteLine(text, lineStart, line, flagged, flags, shiftKey) {
  if (line.trim() === "" || (!flagged && QUOTE_PREFIX.test(line))) return line
  const marker = flagged ? null : parseListMarker(line)
  if (marker) {
    const change = listChange(itemsAbove(text, lineStart, flags), line, shiftKey)
    return change ? change.text + line.slice(change.prefix.length) : line
  }
  return shiftKey ? line.slice(outdentWidth(line)) : `  ${line}`
}

// Each line is rewritten top-down against the text already rewritten above it, so the edit is one replacement.
function blockAction(value, firstStart, lastEnd, shiftKey) {
  const firstIndex = lineIndexOf(value, firstStart)
  const flags = fencedFlags(value, lineIndexOf(value, lastEnd))
  const original = value.slice(firstStart, lastEnd).split("\n")
  let text = value
  let pos = firstStart
  const rewritten = original.map((line, k) => {
    const next = rewriteLine(text, pos, line, flags[firstIndex + k], flags, shiftKey)
    text = text.slice(0, pos) + next + text.slice(pos + line.length)
    pos += next.length + 1
    return next
  })
  const block = rewritten.join("\n")
  if (block === original.join("\n")) return { edit: null }
  return {
    edit: {
      start: firstStart,
      end: lastEnd,
      text: block,
      selectionStart: firstStart,
      selectionEnd: firstStart + block.length
    }
  }
}

// Tab/Shift+Tab. null leaves the key to the browser (IME, or Tab after Esc); { edit: null } swallows it.
export function tabAction({ value, selectionStart, selectionEnd, shiftKey, isComposing, escaped }) {
  if (isComposing || escaped) return null
  const { lineStart, line } = currentLine(value, selectionStart)
  const end = currentLine(value, selectionEnd)
  if (end.lineStart !== lineStart) {
    const lastEnd = end.lineStart === selectionEnd ? selectionEnd - 1 : end.lineEnd
    return blockAction(value, lineStart, lastEnd, shiftKey)
  }

  const lineIndex = lineIndexOf(value, lineStart)
  const flags = fencedFlags(value, lineIndex)
  const flagged = flags[lineIndex]
  if (!flagged && QUOTE_PREFIX.test(line)) return { edit: null }
  const marker = flagged ? null : parseListMarker(line)

  if (marker) {
    const change = listChange(itemsAbove(value, lineStart, flags), line, shiftKey)
    if (!change) return { edit: null }
    const delta = change.text.length - change.prefix.length
    return {
      edit: {
        start: lineStart,
        end: lineStart + change.prefix.length,
        text: change.text,
        selectionStart: Math.max(lineStart, selectionStart + delta),
        selectionEnd: Math.max(lineStart, selectionEnd + delta)
      }
    }
  }

  if (shiftKey) {
    const removed = outdentWidth(line)
    if (removed === 0) return { edit: null }
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

  // A one-line selection is indented from the line start, as code editors do.
  const at = selectionStart === selectionEnd ? selectionStart : lineStart
  return {
    edit: { start: at, end: at, text: "  ", selectionStart: selectionStart + 2, selectionEnd: selectionEnd + 2 }
  }
}
