// String#trim also strips U+3000 and NBSP, which CommonMark treats as content.
const isAsciiSpace = (ch) => ch === " " || ch === "\t" || ch === "\n" || ch === "\r"

export function trimMarkdownStart(markdown) {
  let start = 0
  while (start < markdown.length && isAsciiSpace(markdown[start])) start++
  return markdown.slice(start)
}

export function trimMarkdown(markdown) {
  let end = markdown.length
  while (end > 0 && isAsciiSpace(markdown[end - 1])) end--
  return trimMarkdownStart(markdown.slice(0, end))
}

const LIST_PREFIX = /^(?:[ \t]*(?:>[ \t\u3000\u00A0]?)+)?[ \t]*(?:[-*+]|\d{1,9}[.)])[ \t\u3000\u00A0]+(?:\[[ xX]\][ \t\u3000\u00A0]+)?(?=\S)/
const FENCE_OPEN = /^ {0,3}(`{3,}|~{3,})(.*)$/s
const FENCE_CLOSE = /^ {0,3}(`{3,}|~{3,})[ \t\r]*$/

// inFence covers the opener, the body and the closer.
export function fenceStep(fence, line) {
  if (fence) {
    const close = FENCE_CLOSE.exec(line)
    const closed = close && close[1][0] === fence.char && close[1].length >= fence.length
    return { fence: closed ? null : fence, inFence: true }
  }
  const open = FENCE_OPEN.exec(line)
  if (open && !(open[1][0] === "`" && open[2].includes("`"))) {
    return { fence: { char: open[1][0], length: open[1].length }, inFence: true }
  }
  return { fence: null, inFence: false }
}

export function insideFence(value, lineStart) {
  let fence = null
  let start = 0
  for (;;) {
    const newline = value.indexOf("\n", start)
    const end = newline === -1 ? value.length : newline
    const step = fenceStep(fence, value.slice(start, end))
    if (start === lineStart) return step.inFence
    if (newline === -1) return false
    fence = step.fence
    start = newline + 1
  }
}

export function normalizeListGaps(markdown) {
  let fence = null
  return markdown
    .split("\n")
    .map((line) => {
      const step = fenceStep(fence, line)
      fence = step.fence
      if (step.inFence) return line
      // One character in, one out, so offsets into the source stay valid.
      return line.replace(LIST_PREFIX, (prefix) => prefix.replace(/[\u3000\u00A0]/g, " "))
    })
    .join("\n")
}
