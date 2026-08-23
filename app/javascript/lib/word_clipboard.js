import DOMPurify from "dompurify"
import { marked } from "marked"

const FONT_FAMILY = "'BIZ UDPGothic', 'Yu Gothic', 'Meiryo', sans-serif"
const BODY_FONT_SIZE = "11pt"
const BODY_LINE_HEIGHT = "1.7"

const WORD_STYLES = {
  body: `font-family:${FONT_FAMILY};font-size:${BODY_FONT_SIZE};line-height:${BODY_LINE_HEIGHT};`,
  h1: `font-family:${FONT_FAMILY};font-size:20pt;font-weight:700;line-height:1.4;margin:0 0 12pt 0;`,
  h2: `font-family:${FONT_FAMILY};font-size:16pt;font-weight:700;line-height:1.4;margin:16pt 0 8pt 0;`,
  h3: `font-family:${FONT_FAMILY};font-size:13pt;font-weight:700;line-height:1.5;margin:14pt 0 6pt 0;`,
  h4: `font-family:${FONT_FAMILY};font-size:11pt;font-weight:700;line-height:1.5;margin:12pt 0 4pt 0;`,
  paragraph: `font-family:${FONT_FAMILY};font-size:${BODY_FONT_SIZE};line-height:${BODY_LINE_HEIGHT};margin:0 0 8pt 0;`,
  blockquote: `font-family:${FONT_FAMILY};font-size:${BODY_FONT_SIZE};line-height:${BODY_LINE_HEIGHT};margin:8pt 0;padding-left:10pt;border-left:3pt solid #adb5bd;color:#555555;`,
  list: `font-family:${FONT_FAMILY};font-size:${BODY_FONT_SIZE};line-height:${BODY_LINE_HEIGHT};margin:0 0 8pt 0;`,
  table: `font-family:${FONT_FAMILY};font-size:${BODY_FONT_SIZE};line-height:1.5;border-collapse:collapse;width:100%;`,
  cell: `font-family:${FONT_FAMILY};font-size:${BODY_FONT_SIZE};padding:4pt 6pt;border:0.5pt solid #b7b7b7;vertical-align:top;`,
  code: `font-family:'MS Gothic','Courier New',monospace;font-size:10pt;line-height:1.5;`,
  pre: `font-family:'MS Gothic','Courier New',monospace;font-size:10pt;line-height:1.5;background:#f3f3f3;padding:8pt;margin:8pt 0;white-space:pre-wrap;`,
  link: `font-family:${FONT_FAMILY};font-size:${BODY_FONT_SIZE};`,
}

function styleTree(root) {
  root.querySelectorAll("h1,h2,h3,h4,h5,h6,p,blockquote,ul,ol,table,thead,tbody,tr,th,td,pre,code,a").forEach((element) => {
    const tag = element.tagName.toLowerCase()

    if (/^h[1-6]$/.test(tag)) {
      element.setAttribute("style", WORD_STYLES[`h${tag.slice(1)}`] || WORD_STYLES.h4)
    } else if (tag === "p") {
      element.setAttribute("style", WORD_STYLES.paragraph)
    } else if (tag === "blockquote") {
      element.setAttribute("style", WORD_STYLES.blockquote)
    } else if (tag === "ul" || tag === "ol") {
      element.setAttribute("style", WORD_STYLES.list)
    } else if (tag === "table") {
      element.setAttribute("style", WORD_STYLES.table)
    } else if (tag === "th" || tag === "td") {
      element.setAttribute("style", WORD_STYLES.cell)
    } else if (tag === "pre") {
      element.setAttribute("style", WORD_STYLES.pre)
    } else if (tag === "code") {
      element.setAttribute("style", WORD_STYLES.code)
    } else if (tag === "a") {
      element.setAttribute("style", WORD_STYLES.link)
    }
  })
}

function buildPlainText(markdown) {
  const html = marked.parse(markdown.trim())
  const container = document.createElement("div")
  container.innerHTML = DOMPurify.sanitize(html, { USE_PROFILES: { html: true } })
  return container.innerText.trim()
}

export function buildWordClipboard(markdown) {
  const renderedHtml = marked.parse(markdown.trim())
  const sanitizedHtml = DOMPurify.sanitize(renderedHtml, { USE_PROFILES: { html: true } })
  const container = document.createElement("div")
  container.innerHTML = sanitizedHtml
  styleTree(container)

  const wrapper = document.createElement("div")
  wrapper.setAttribute("style", WORD_STYLES.body)
  wrapper.innerHTML = container.innerHTML

  return {
    html: wrapper.outerHTML,
    text: buildPlainText(markdown),
  }
}

export async function copyAsWordRichText(markdown) {
  if (!navigator.clipboard?.write || typeof ClipboardItem === "undefined") {
    throw new Error("Rich text clipboard is not supported by this browser")
  }

  const { html, text } = buildWordClipboard(markdown)
  const item = new ClipboardItem({
    "text/html": new Blob([html], { type: "text/html" }),
    "text/plain": new Blob([text], { type: "text/plain" }),
  })

  await navigator.clipboard.write([item])
}
