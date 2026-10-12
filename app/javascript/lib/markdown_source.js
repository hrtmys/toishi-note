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

export function normalizeListGaps(markdown) {
  let fence = null
  return markdown
    .split("\n")
    .map((line) => {
      if (fence) {
        const close = FENCE_CLOSE.exec(line)
        if (close && close[1][0] === fence.char && close[1].length >= fence.length) fence = null
        return line
      }
      const open = FENCE_OPEN.exec(line)
      if (open && !(open[1][0] === "`" && open[2].includes("`"))) {
        fence = { char: open[1][0], length: open[1].length }
        return line
      }
      // One character in, one out, so offsets into the source stay valid.
      return line.replace(LIST_PREFIX, (prefix) => prefix.replace(/[\u3000\u00A0]/g, " "))
    })
    .join("\n")
}
