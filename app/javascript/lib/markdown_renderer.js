import DOMPurify from "dompurify"
import { marked } from "marked"

// hljs, KaTeX, and Mermaid are each several hundred KB and only needed by
// the fraction of notes with a code block, math, or diagram. Loaded on
// demand, gated by a cheap content check, so the common case pays nothing.
let mermaidConfigured = false

async function ensureMermaidConfigured() {
  const mermaid = (await import("mermaid")).default
  if (!mermaidConfigured) {
    mermaid.initialize({ startOnLoad: false, theme: "default" })
    mermaidConfigured = true
  }
  return mermaid
}

// Splits fenced code blocks into "Mermaid diagram" vs. "everything else"
// up front — a code block wrongly treated as a diagram would silently
// show nothing.
function partitionCodeBlocks(element) {
  const mermaidBlocks = []
  const codeBlocks = []

  element.querySelectorAll("pre code").forEach((block) => {
    if (block.classList.contains("language-mermaid") || block.classList.contains("mermaid")) {
      mermaidBlocks.push(block)
    } else {
      codeBlocks.push(block)
    }
  })

  return { mermaidBlocks, codeBlocks }
}

async function highlightCodeBlocks(codeBlocks) {
  if (codeBlocks.length === 0) return

  const hljs = (await import("highlight.js")).default
  codeBlocks.forEach((block) => hljs.highlightElement(block))
}

async function renderMermaidBlocks(mermaidBlocks) {
  if (mermaidBlocks.length === 0) return

  const mermaid = await ensureMermaidConfigured()

  const diagrams = mermaidBlocks.map((block) => {
    const container = document.createElement("div")
    container.classList.add("mermaid")
    container.textContent = block.textContent
    block.closest("pre")?.replaceWith(container)
    return container
  })

  mermaid.run({ nodes: diagrams }).catch(console.error)
}

// KaTeX's auto-render walks every text node looking for delimiters —
// wasted work on a note with no math. Testing the raw source up front is
// only a load/skip gate; auto-render still does the precise matching.
const MATH_DELIMITER_PATTERN = /\$\$|\$[^\s$]|\\\(|\\\[/

async function renderMath(element, markdown) {
  if (!MATH_DELIMITER_PATTERN.test(markdown)) return

  const renderMathInElement = (await import("katex/dist/contrib/auto-render.mjs")).default

  renderMathInElement(element, {
    delimiters: [
      { left: "$$", right: "$$", display: true },
      { left: "$", right: "$", display: false },
      { left: "\\(", right: "\\)", display: false },
      { left: "\\[", right: "\\]", display: true }
    ],
    throwOnError: false
  })
}

// Always sanitized, no opt-out — every caller's input is user-typed, and
// an opt-out is a future XSS bug waiting to happen.
export function renderMarkdownIntoElement(element, markdown) {
  const html = marked.parse(markdown.trim())
  element.innerHTML = DOMPurify.sanitize(html)

  const { mermaidBlocks, codeBlocks } = partitionCodeBlocks(element)
  highlightCodeBlocks(codeBlocks)
  renderMermaidBlocks(mermaidBlocks)
  renderMath(element, markdown)
}
