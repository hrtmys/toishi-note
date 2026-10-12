// Unit tests for lib/scroll_follow.js.
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as scrollFollow from "../../app/javascript/lib/scroll_follow.js"

const view = { scrollTop: 100, viewHeight: 200, maxScrollTop: 1000, margin: 10 }

function reveal(top, bottom) {
  return scrollFollow.revealScrollTop({ top, bottom, ...view })
}

// The caret is written as "|" in the source, as in the editor tests.
function anchorAt(marked) {
  return scrollFollow.previewAnchor(marked.replace("|", ""), marked.indexOf("|"))
}

describe("revealScrollTop", () => {
  it("leaves a band inside the margins alone", () => {
    assert.equal(reveal(150, 170), null)
  })

  it("leaves a band exactly on the margins alone", () => {
    assert.equal(reveal(110, 290), null)
  })

  it("scrolls down by the minimal amount for a band below the view", () => {
    assert.equal(reveal(290, 310), 120)
  })

  it("scrolls up to the top margin for a band above the view", () => {
    assert.equal(reveal(80, 100), 70)
  })

  it("clamps a scroll past the maximum to the maximum", () => {
    assert.equal(reveal(1180, 1200), 1000)
  })

  it("clamps a scroll below zero to zero", () => {
    assert.equal(reveal(5, 25), 0)
  })

  it("aligns a band taller than the view to the top margin", () => {
    assert.equal(reveal(400, 700), 390)
  })
})

describe("previewAnchor", () => {
  it("anchors a caret in a paragraph after a heading to the paragraph", () => {
    assert.deepEqual(anchorAt("# A\n\npara|"), { block: 1, start: 0, end: 1, count: 2 })
  })

  it("places a caret on the second line of a list at its quarter share", () => {
    assert.deepEqual(anchorAt("- a\n- b|\n- c\n- d"), { block: 0, start: 0.25, end: 0.5, count: 1 })
  })

  it("takes the previous block's last-line share for a caret on a blank line between blocks", () => {
    assert.deepEqual(anchorAt("# A\n\n|\n\npara"), { block: 0, start: 0, end: 1, count: 2 })
  })

  it("clamps trailing blank lines to the last block", () => {
    assert.deepEqual(anchorAt("# A\n\npara\n\n|"), { block: 1, start: 0, end: 1, count: 2 })
  })

  it("trims leading whitespace before counting the caret's position", () => {
    assert.deepEqual(anchorAt("\n\n# A\n\nb|"), { block: 1, start: 0, end: 1, count: 2 })
  })

  it("does not count a link reference definition as a block", () => {
    assert.deepEqual(anchorAt("[r]: https://x\n\nafter|"), { block: 0, start: 0, end: 1, count: 1 })
  })

  it("takes the caret's line share inside a fenced code block, fence lines included", () => {
    assert.deepEqual(anchorAt("```js\nx\n|y\n```"), { block: 0, start: 0.5, end: 0.75, count: 1 })
  })

  it("falls back to the whole document when an html block is present", () => {
    assert.deepEqual(anchorAt("a\n\n<div>x</div>\n\nb|"), { block: null, start: 0.8, end: 1, count: null })
  })

  it("returns null for an empty or whitespace-only document", () => {
    assert.equal(scrollFollow.previewAnchor("", 0), null)
    assert.equal(scrollFollow.previewAnchor("  \n\n ", 3), null)
  })

  it("counts caret offsets in UTF-16 code units across surrogate pairs", () => {
    assert.deepEqual(anchorAt("😀😀\n\nb|"), { block: 1, start: 0, end: 1, count: 2 })
  })
})
