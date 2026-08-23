import { diffWordsWithSpace } from "diff"
import DOMPurify from "dompurify"

// Renders a word-level diff between two texts as HTML: additions get a
// green underline, removals a red strikethrough. A plain function, not a
// controller method, so it has no opinion on where the text came from.
export function renderDiffHtml(before, after) {
  const parts = diffWordsWithSpace(before, after)

  const html = parts.map((part) => {
    const escaped = escapeHtml(part.value)

    if (part.added) return `<ins class="diff-added">${escaped}</ins>`
    if (part.removed) return `<del class="diff-removed">${escaped}</del>`
    return escaped
  }).join("")

  return DOMPurify.sanitize(html, { ALLOWED_TAGS: [ "ins", "del" ], ALLOWED_ATTR: [ "class" ] })
}

function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}
