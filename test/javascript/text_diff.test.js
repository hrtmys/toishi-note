// Unit tests for lib/text_diff.js. The XSS case mirrors the payload
// in test/system/security_test.rb.
import "./helpers/jsdom_setup.js"
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { compareState, renderDiffHtml } from "../../app/javascript/lib/text_diff.js"

describe("renderDiffHtml", () => {
  it("highlights the word-level diff between two texts", () => {
    const result = renderDiffHtml("The quick brown fox", "The quick red fox jumps")
    assert.match(result, /<del class="diff-removed">brown<\/del>/)
    assert.match(result, /<ins class="diff-added">red<\/ins>/)
    assert.match(result, /<ins class="diff-added">[\s\S]*jumps[\s\S]*<\/ins>/)
  })

  it("emits no ins/del for identical texts", () => {
    const result = renderDiffHtml("Same text", "Same text")
    assert.doesNotMatch(result, /<ins/)
    assert.doesNotMatch(result, /<del/)
    assert.match(result, /Same text/)
  })

  it("neutralizes an XSS payload into inert text", () => {
    const payload = `<img src="x" onerror="window.__xss_fired = true">`
    for (const result of [renderDiffHtml(payload, "safe"), renderDiffHtml("safe", payload)]) {
      // No real tag survives: angle brackets are escaped, so the payload
      // renders as visible text and no element carries an onerror handler.
      assert.doesNotMatch(result, /<img/)
      assert.doesNotMatch(result, /<[^>]*onerror/)
      assert.match(result, /&lt;img/)
    }
  })
})

describe("compareState", () => {
  it("is empty only when both sides are empty", () => {
    assert.equal(compareState("", ""), "empty")
    assert.equal(compareState("", "a"), "changed")
    assert.equal(compareState("a", ""), "changed")
  })

  it("is unchanged for identical text, including Japanese", () => {
    assert.equal(compareState("a", "a"), "unchanged")
    assert.equal(compareState("砥石\nノート", "砥石\nノート"), "unchanged")
  })

  it("counts whitespace-only edits as changes", () => {
    assert.equal(compareState("a", "b"), "changed")
    assert.equal(compareState("a", "a "), "changed")
    assert.equal(compareState("a\n", "a"), "changed")
  })
})
