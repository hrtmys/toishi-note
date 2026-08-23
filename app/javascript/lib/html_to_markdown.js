import TurndownService from "turndown"
import { gfm } from "turndown-plugin-gfm"

// The core HTML → Markdown conversion for pasted Word/Excel/Sheets
// content. Rides on Turndown + turndown-plugin-gfm rather than
// reimplementing table conversion.
const turndownService = new TurndownService({ headingStyle: "atx", codeBlockStyle: "fenced" })
turndownService.use(gfm)

// Turndown has no built-in denylist for non-content tags. `extractBodyHtml`
// already excludes <head>, so this is a backstop for a stray <style>/
// <script> in the body. `o:p` is Word's empty-paragraph marker artifact.
turndownService.remove([ "style", "script", "o:p" ])

export function convertHtmlToMarkdown(html) {
  return turndownService.turndown(extractBodyHtml(html)).trim()
}

// A bare clipboard wrapper with no real formatting isn't worth
// converting — a cheap pre-check so callers can skip it for plain text.
export function looksLikeRichContent(html) {
  return /<(table|b|strong|i|em|ul|ol|h[1-6]|blockquote|code|a[\s>])/i.test(html)
}

// Distinguishes an Excel/Sheets range (a <table>) from plain Word rich
// text — word_paste_controller.js uses this to decide "convert on
// demand from the FAB" vs. "convert automatically".
export function looksLikeTable(html) {
  return /<table[\s>]/i.test(html)
}

// Parsing through DOMParser and keeping only document.body's HTML drops
// everything under <head> (Word's mso metadata etc.) structurally, before
// Turndown ever sees it. A plain HTML fragment parses unchanged.
function extractBodyHtml(html) {
  const doc = new DOMParser().parseFromString(html, "text/html")
  expandMergedCells(doc)
  normalizeSpreadsheetHeaderRow(doc)
  return doc.body.innerHTML
}

// Excel merged cells (rowspan/colspan) misalign columns once GFM renders
// the table. Expand every table into a rectangular grid first — one real
// <td> per visual cell — flattening grouped headers rather than nesting them.
function expandMergedCells(doc) {
  doc.querySelectorAll("table").forEach((table) => {
    const rows = Array.from(table.rows)
    const grid = []
    const emptyRows = new Set() // rows with no cells of their own — pure rowspan continuations

    rows.forEach((row, r) => {
      if (!grid[r]) grid[r] = []
      if (row.cells.length === 0) emptyRows.add(r)
      let col = 0

      Array.from(row.cells).forEach((cell) => {
        while (grid[r][col] !== undefined) col++ // skip columns already filled by an earlier row's rowspan

        const rowspan = cell.rowSpan || 1
        const colspan = cell.colSpan || 1
        for (let dr = 0; dr < rowspan; dr++) {
          if (!grid[r + dr]) grid[r + dr] = []
          for (let dc = 0; dc < colspan; dc++) {
            grid[r + dr][col + dc] = cell.innerHTML
          }
        }

        col += colspan
      })
    })

    const columnCount = grid.reduce((max, gridRow) => Math.max(max, gridRow.length), 0)

    rows.forEach((row, r) => {
      if (emptyRows.has(r)) {
        row.remove() // fully absorbed into the rows above via rowspan — not a real row
        return
      }

      Array.from(row.cells).forEach((cell) => cell.remove())
      for (let c = 0; c < columnCount; c++) {
        const td = doc.createElement("td")
        td.innerHTML = grid[r]?.[c] ?? ""
        row.appendChild(td)
      }
    })
  })
}

// A row where every cell holds identical content is Excel's full-width
// title/caption, not real headers — expandMergedCells duplicated it into
// every grid position. Skip it so the real header gets promoted.
function isSpanningTitleRow(row) {
  const cells = Array.from(row.cells)
  return cells.length > 1 && cells.every((cell) => cell.innerHTML === cells[0].innerHTML)
}

// Excel clipboard HTML never marks its header row with <thead>/<th>, but
// turndown-plugin-gfm needs one. Build a real <thead>, promoting <td> to <th>.
function normalizeSpreadsheetHeaderRow(doc) {
  doc.querySelectorAll("table").forEach((table) => {
    const rows = Array.from(table.rows)
    const headerRow = rows.find((row) => !isSpanningTitleRow(row)) || rows[0]
    if (!headerRow || headerRow.closest("thead")) return

    Array.from(headerRow.cells).forEach((cell) => {
      if (cell.tagName === "TH") return
      const heading = doc.createElement("th")
      heading.innerHTML = cell.innerHTML
      cell.replaceWith(heading)
    })

    const thead = doc.createElement("thead")
    thead.appendChild(headerRow) // moves it out of wherever it lived before
    table.insertBefore(thead, table.firstChild)
  })

  return doc
}
