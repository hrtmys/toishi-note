import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { looksLikeRichContent, looksLikeTable } from "../../app/javascript/lib/html_to_markdown.js"

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
