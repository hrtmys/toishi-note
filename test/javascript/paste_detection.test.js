import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { classifyPaste, looksLikeRichContent, looksLikeTable } from "../../app/javascript/lib/html_to_markdown.js"
import { EXCEL_HTML, WORD_HTML } from "./helpers/office_paste_fixtures.js"

const classify = (html, extra = {}) =>
  classifyPaste({ html, hasImage: false, shiftHeld: false, isComposing: false, ...extra })

describe("classifyPaste", () => {
  it("converts Word and styled rich content", () => {
    assert.equal(classify(WORD_HTML), "convert")
    assert.equal(classify("<p class=MsoNormal>hi<o:p></o:p></p>"), "convert")
    assert.equal(classify('<span style="font-weight:bold">x</span>'), "convert")
  })

  it("passes plain HTML and image-only pastes through", () => {
    assert.equal(classify("<span>plain</span>"), "passthrough")
    assert.equal(classify("", { hasImage: true }), "passthrough")
  })

  it("routes spreadsheet HTML to the table prompt instead of converting", () => {
    assert.equal(classify(EXCEL_HTML), "table")
  })

  it("lets Shift and IME composition keep the browser's paste", () => {
    assert.equal(classify(WORD_HTML, { shiftHeld: true }), "passthrough")
    assert.equal(classify(WORD_HTML, { isComposing: true }), "passthrough")
  })

  it("still converts Word HTML that carries a rendered image", () => {
    assert.equal(classify(WORD_HTML, { hasImage: true }), "convert")
  })
})

describe("looksLikeRichContent", () => {
  it("matches explicit rich tags", () => {
    assert.equal(looksLikeRichContent("<p><b>Bold</b> and normal.</p>"), true)
    assert.equal(looksLikeRichContent("<table><tr><td>x</td></tr></table>"), true)
  })

  it("matches Word markers with no rich tags", () => {
    assert.equal(looksLikeRichContent("<p class=MsoNormal>hi<o:p></o:p></p>"), true)
    assert.equal(looksLikeRichContent('<p style="mso-bidi-font-weight:normal">hi</p>'), true)
    assert.equal(looksLikeRichContent('<html xmlns:w="urn:schemas-microsoft-com:office:word">'), true)
  })

  it("matches styled paragraphs but not bare spans or plain text", () => {
    assert.equal(looksLikeRichContent('<p style="margin:0">x</p>'), true)
    assert.equal(looksLikeRichContent('<span class="x">y</span>'), true)
    assert.equal(looksLikeRichContent("<span>plain</span>"), false)
    assert.equal(looksLikeRichContent("just plain text"), false)
  })
})

describe("looksLikeTable", () => {
  it("matches table tags case-insensitively", () => {
    assert.equal(looksLikeTable("<table><tr><td>x</td></tr></table>"), true)
    assert.equal(looksLikeTable("<TABLE cellpadding=0>"), true)
    assert.equal(looksLikeTable("<p><b>Bold</b></p>"), false)
  })
})
