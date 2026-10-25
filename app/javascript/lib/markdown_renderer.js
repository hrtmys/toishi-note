import DOMPurify from "dompurify"
import { marked } from "./marked_config.js"
import { normalizeListGaps, trimMarkdown } from "./markdown_source.js"

// hljs, KaTeX, and Mermaid are each several hundred KB and only needed by
// the fraction of notes with a code block, math, or diagram. Loaded on
// demand, gated by a cheap content check, so the common case pays nothing.
let mermaidConfigured = false

// Indirected so tests can substitute a fake: the real Mermaid measures
// text through browser layout APIs, so it never finishes a render under
// jsdom. Production code always uses the default loader.
let mermaidModuleLoader = () => import("mermaid")

export function setMermaidModuleLoaderForTest(loader) {
  mermaidModuleLoader = loader
  mermaidConfigured = false
}

// The Note editor re-renders the preview on every keystroke (debounced),
// unlike a Scrap item's one-shot render — so an older call's Mermaid
// import/render can still be in flight when a newer keystroke replaces
// the same element's content out from under it. Tracking the latest call
// per element lets a stale one recognize it's been superseded and bail
// instead of touching nodes a newer render already tore out of the DOM.
const latestRenderPerElement = new WeakMap()

async function ensureMermaidConfigured() {
  const mermaid = (await mermaidModuleLoader()).default
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

async function highlightCodeBlocks(codeBlocks, element, token) {
  if (codeBlocks.length === 0) return

  const hljs = (await import("highlight.js")).default
  if (latestRenderPerElement.get(element) !== token) return

  codeBlocks.forEach((block) => hljs.highlightElement(block))
}

// Each mermaid.render() call needs a document-unique id; a module counter
// guarantees it even when two renders overlap mid-typing.
let mermaidRenderSeq = 0

// Rebuilding innerHTML on every render destroys the SVG a previous
// render produced, so an unchanged diagram would be re-rendered from
// scratch on every keystroke — the flicker. Cache SVGs by source text.
const mermaidSvgCache = new Map()
const MERMAID_SVG_CACHE_LIMIT = 50

function cacheMermaidSvg(source, svg) {
  // Editing a diagram leaves one entry per intermediate valid state,
  // but only recent diagrams matter — drop the whole cache at the limit
  // rather than track eviction order.
  if (mermaidSvgCache.size >= MERMAID_SVG_CACHE_LIMIT) mermaidSvgCache.clear()
  mermaidSvgCache.set(source, svg)
}

function swapInMermaidSvg(block, svg) {
  const container = document.createElement("div")
  container.classList.add("mermaid")
  container.innerHTML = svg
  const pre = block.closest("pre")
  if (pre) {
    pre.replaceWith(container)
  } else {
    block.replaceWith(container)
  }
}

async function renderMermaidBlocks(mermaidBlocks, element, token) {
  if (mermaidBlocks.length === 0) return

  // Cache hits swap in here, before the first await — after this
  // function's caller has rebuilt the element, a hit must land in the
  // same synchronous pass or the raw code block paints for a frame.
  const uncachedBlocks = []
  for (const block of mermaidBlocks) {
    const cachedSvg = mermaidSvgCache.get(block.textContent)
    if (cachedSvg) {
      swapInMermaidSvg(block, cachedSvg)
    } else {
      uncachedBlocks.push(block)
    }
  }
  if (uncachedBlocks.length === 0) return

  let mermaid
  try {
    mermaid = await ensureMermaidConfigured()
  } catch (error) {
    console.error(error)
    return
  }
  if (latestRenderPerElement.get(element) !== token) return

  // Render each diagram off-DOM and swap it in only on success, so a
  // superseded render or a syntax error mid-typing never leaves an empty
  // div where the code block was. The previous <pre> stays until then.
  for (let index = 0; index < uncachedBlocks.length; index++) {
    const block = uncachedBlocks[index]
    if (latestRenderPerElement.get(element) !== token) return
    if (!block.isConnected) return

    const source = block.textContent

    // A duplicate of this diagram earlier in the same pass may have
    // filled the cache while this render was being set up.
    const cachedSvg = mermaidSvgCache.get(source)
    if (cachedSvg) {
      swapInMermaidSvg(block, cachedSvg)
      continue
    }

    let svg
    try {
      mermaidRenderSeq += 1
      const renderId = `mermaid-live-${mermaidRenderSeq.toString(36)}-${index.toString(36)}`
      const result = await mermaid.render(renderId, source)
      svg = result.svg
    } catch {
      // Half-typed or invalid syntax while typing is expected — keep the
      // original code block so the input never flickers into an empty div.
      continue
    }

    if (latestRenderPerElement.get(element) !== token) return
    if (!block.isConnected) return

    cacheMermaidSvg(source, svg)
    swapInMermaidSvg(block, svg)
  }
}

// KaTeX's auto-render walks every text node looking for delimiters —
// wasted work on a note with no math. Testing the raw source up front is
// only a load/skip gate; auto-render still does the precise matching.
const MATH_DELIMITER_PATTERN = /\$\$|\$[^\s$]|\\\(|\\\[/

async function renderMath(element, markdown, token) {
  if (!MATH_DELIMITER_PATTERN.test(markdown)) return

  let renderMathInElement
  try {
    renderMathInElement = (await import("katex/dist/contrib/auto-render.mjs")).default
  } catch (error) {
    console.error(error)
    return
  }
  if (latestRenderPerElement.get(element) !== token) return

  // Synchronous, so no race can interleave past this point — but a stale
  // call must still bail here instead of walking a superseded tree.
  try {
    renderMathInElement(element, {
      delimiters: [
        { left: "$$", right: "$$", display: true },
        { left: "$", right: "$", display: false },
        { left: "\\(", right: "\\)", display: false },
        { left: "\\[", right: "\\]", display: true }
      ],
      throwOnError: false
    })
  } catch (error) {
    console.error(error)
  }
}

// Always sanitized, no opt-out — every caller's input is user-typed, and
// an opt-out is a future XSS bug waiting to happen.
export function renderMarkdownIntoElement(element, markdown) {
  const token = Symbol("markdown-render")
  latestRenderPerElement.set(element, token)

  const html = marked.parse(normalizeListGaps(trimMarkdown(markdown)))
  element.innerHTML = DOMPurify.sanitize(html)

  const { mermaidBlocks, codeBlocks } = partitionCodeBlocks(element)
  highlightCodeBlocks(codeBlocks, element, token)
  renderMermaidBlocks(mermaidBlocks, element, token)
  renderMath(element, markdown, token)
}
