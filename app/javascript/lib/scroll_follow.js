import { marked } from "marked"

const RENDERED = new Set([ "heading", "paragraph", "list", "blockquote", "code", "table", "hr" ])
const SILENT = new Set([ "space", "def" ])

export function revealScrollTop({ top, bottom, scrollTop, viewHeight, maxScrollTop, margin }) {
  if (top >= scrollTop + margin && bottom <= scrollTop + viewHeight - margin) return null

  const target = bottom - top > viewHeight - 2 * margin || top < scrollTop + margin
    ? top - margin
    : bottom + margin - viewHeight

  return Math.min(Math.max(target, 0), maxScrollTop)
}

export function revealCaret(textarea) {
  if (textarea.scrollHeight <= textarea.clientHeight) return

  const style = getComputedStyle(textarea)
  const paddingTop = parseFloat(style.paddingTop)
  const paddingX = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight)
  const { value, selectionEnd } = textarea
  const lineEnd = value.indexOf("\n", selectionEnd)
  const restOfLine = value.slice(selectionEnd, lineEnd === -1 ? value.length : lineEnd)

  // A textarea exposes no caret coordinates, so lay out a same-width copy of its text.
  const mirror = document.createElement("div")
  Object.assign(mirror.style, {
    position: "absolute",
    visibility: "hidden",
    top: "0",
    left: "-9999px",
    boxSizing: "content-box",
    width: `${textarea.clientWidth - paddingX}px`,
    padding: "0",
    border: "0",
    whiteSpace: "pre-wrap",
    overflowWrap: "break-word",
    font: style.font,
    lineHeight: style.lineHeight,
    letterSpacing: style.letterSpacing,
    wordSpacing: style.wordSpacing,
    tabSize: style.tabSize,
    wordBreak: style.wordBreak,
  })
  const span = document.createElement("span")
  span.textContent = restOfLine === "" ? "." : restOfLine
  mirror.append(document.createTextNode(value.slice(0, selectionEnd)), span)

  document.body.append(mirror)
  try {
    const rect = span.getClientRects()[0]
    // An inline rect covers only the glyphs; widen it to the full line box.
    const lineHeight = parseFloat(style.lineHeight) || rect.height
    const middle = (rect.top + rect.bottom) / 2 - mirror.getBoundingClientRect().top + paddingTop
    const next = revealScrollTop({
      top: middle - lineHeight / 2,
      bottom: middle + lineHeight / 2,
      scrollTop: textarea.scrollTop,
      viewHeight: textarea.clientHeight,
      maxScrollTop: textarea.scrollHeight - textarea.clientHeight,
      margin: paddingTop,
    })
    // scrollTop rather than value or focus(), which would disturb the undo stack and focus.
    if (next !== null) textarea.scrollTop = next
  } finally {
    mirror.remove()
  }
}

export function previewAnchor(markdown, caret) {
  const trimmed = markdown.trim()
  if (trimmed === "") return null

  const leading = markdown.length - markdown.trimStart().length
  const at = Math.min(Math.max(caret - leading, 0), trimmed.length)

  const tokens = marked.lexer(trimmed)
  const sourceKept = tokens.map((token) => token.raw).join("") === trimmed
  const typesKnown = tokens.every((token) => RENDERED.has(token.type) || SILENT.has(token.type))
  if (!sourceKept || !typesKnown) return wholeDocument(trimmed, at)

  const blocks = []
  let offset = 0
  for (const token of tokens) {
    if (RENDERED.has(token.type)) blocks.push({ start: offset, raw: token.raw })
    offset += token.raw.length
  }
  if (blocks.length === 0) return wholeDocument(trimmed, at)

  const index = Math.max(blocks.findLastIndex((block) => block.start <= at), 0)
  const block = blocks[index]

  // marked's raw swallows trailing newlines; they are not lines of the block.
  const text = block.raw.replace(/\n+$/, "")
  const lines = countNewlines(text) + 1
  if (lines === 1) {
    // A soft-wrapped paragraph can be taller than the view; aim at the caret, not the block top.
    const share = Math.min(Math.max((at - block.start) / text.length, 0), 1)
    return { block: index, start: share, end: share, count: blocks.length }
  }
  const { start, end } = lineShare(lines, countNewlines(trimmed.slice(block.start, at)))

  return { block: index, start, end, count: blocks.length }
}

function wholeDocument(trimmed, at) {
  const lines = countNewlines(trimmed) + 1
  const { start, end } = lineShare(lines, countNewlines(trimmed.slice(0, at)))

  return { block: null, start, end, count: null }
}

function lineShare(lines, newlines) {
  const line = Math.min(newlines, lines - 1)

  return { start: line / lines, end: (line + 1) / lines }
}

function countNewlines(text) {
  return text.split("\n").length - 1
}
