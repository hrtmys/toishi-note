// Unit tests for lib/html_to_markdown.js. Fixtures mirror the
// real-paste shapes from word_excel_paste_test.rb (now wiring-only).
import "./helpers/jsdom_setup.js"
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { convertHtmlToMarkdown } from "../../app/javascript/lib/html_to_markdown.js"

const basicTable = `<html xmlns:x="urn:schemas-microsoft-com:office:excel">
<body>
<table border=0 cellpadding=0 cellspacing=0 width=192>
 <col width=96 span=2>
 <tr height=20>
  <td height=20 class=xl65 width=96>Name</td>
  <td class=xl65 width=96>Score</td>
 </tr>
 <tr height=20>
  <td height=20 class=xl65>Alice</td>
  <td class=xl65>90</td>
 </tr>
</table>
</body>
</html>`

const rowspanHeaderTable = `<html xmlns:x="urn:schemas-microsoft-com:office:excel">
<body>
<table border=0 cellpadding=0 cellspacing=0 width=140>
 <col width=70 span=2>
 <tr height=25>
  <td rowspan=2 class=xl69 width=70>group</td>
  <td rowspan=2 class=xl71 width=70>count</td>
 </tr>
 <tr height=25>
 </tr>
 <tr height=25>
  <td height=25 class=xl67 width=70>sample</td>
  <td class=xl68>18</td>
 </tr>
</table>
</body>
</html>`

const colspanHeaderTable = `<html xmlns:x="urn:schemas-microsoft-com:office:excel">
<body>
<table border=0 cellpadding=0 cellspacing=0 width=280>
 <col width=70 span=4>
 <tr height=25>
  <td colspan=2 class=xl69 width=140>Group A</td>
  <td colspan=2 class=xl69 width=140>Group B</td>
 </tr>
 <tr height=25>
  <td class=xl67 width=70>Name</td>
  <td class=xl67 width=70>Score</td>
  <td class=xl67 width=70>Name</td>
  <td class=xl67 width=70>Score</td>
 </tr>
 <tr height=25>
  <td class=xl68 width=70>Alice</td>
  <td class=xl68>90</td>
  <td class=xl68 width=70>Bob</td>
  <td class=xl68>85</td>
 </tr>
</table>
</body>
</html>`

const titleRowTable = `<html xmlns:x="urn:schemas-microsoft-com:office:excel">
<body>
<table border=0 cellpadding=0 cellspacing=0 width=140>
 <col width=70 span=2>
 <tr height=25>
  <td colspan=2 class=xl92 width=140>Summary</td>
 </tr>
 <tr height=25>
  <td class=xl67 width=70>Name</td>
  <td class=xl67 width=70>Score</td>
 </tr>
 <tr height=25>
  <td class=xl68 width=70>Alice</td>
  <td class=xl68>90</td>
 </tr>
</table>
</body>
</html>`

describe("convertHtmlToMarkdown", () => {
  it("converts a basic Excel range to a GFM table", () => {
    assert.equal(
      convertHtmlToMarkdown(basicTable),
      "| Name | Score |\n| --- | --- |\n| Alice | 90 |"
    )
  })

  it("expands a merged rowspan header without a phantom empty row", () => {
    const result = convertHtmlToMarkdown(rowspanHeaderTable)
    assert.match(result, /\|\s*group\s*\|\s*count\s*\|/)
    assert.match(result, /\|\s*-+\s*\|\s*-+\s*\|/)
    assert.match(result, /\|\s*sample\s*\|\s*18\s*\|/)
    // The row the rowspan header merges into has no cells of its own —
    // it must not resurface as a separate, blank table row.
    assert.doesNotMatch(result, /^\s*\|\s*\|\s*\|\s*$/m)
  })

  it("keeps every row's column count consistent for a colspan-grouped header", () => {
    const result = convertHtmlToMarkdown(colspanHeaderTable)
    const rows = result.split("\n").map((line) => line.trim()).filter((line) => line.startsWith("|"))
    assert.equal(rows.length, 4)
    const columnCounts = new Set(rows.map((row) => (row.match(/\|/g) || []).length))
    assert.equal(columnCounts.size, 1)
    assert.match(rows.at(-1), /Alice.*90.*Bob.*85/)
  })

  it("promotes the real header, not a full-width title row", () => {
    const result = convertHtmlToMarkdown(titleRowTable)
    const rows = result.split("\n").map((line) => line.trim()).filter((line) => line.startsWith("|"))
    assert.match(result, /\|\s*Alice\s*\|\s*90\s*\|/)
    assert.equal(rows[0], "| Name | Score |")
    assert.match(rows[1], /^\|\s*-+\s*\|\s*-+\s*\|$/)
  })
})
