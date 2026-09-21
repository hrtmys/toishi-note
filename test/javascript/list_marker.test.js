// Unit tests for lib/list_marker.js. Mirrors the MARKERS matrix
// from list_continuation_test.rb (now dash-wiring only).
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { currentLine, parseListMarker, renumberFollowingLines } from "../../app/javascript/lib/list_marker.js"

describe("parseListMarker", () => {
  it("continues a dash bullet unchanged", () => {
    assert.deepEqual(parseListMarker("- first"), { full: "- ", rest: "first", continued: "- " })
  })

  it("continues a star bullet unchanged", () => {
    assert.deepEqual(parseListMarker("* first"), { full: "* ", rest: "first", continued: "* " })
  })

  it("increments an ordered marker", () => {
    assert.deepEqual(parseListMarker("1. first"), {
      full: "1. ",
      rest: "first",
      continued: "2. ",
      ordered: { indent: "", number: 1, delimiter: "." }
    })
  })

  it("increments multi-digit ordered markers past the carry", () => {
    assert.equal(parseListMarker("9. item").continued, "10. ")
  })

  it("continues a task item unchecked", () => {
    assert.deepEqual(parseListMarker("- [ ] todo"), { full: "- [ ] ", rest: "todo", continued: "- [ ] " })
  })

  it("resets a checked task item to unchecked on continue", () => {
    assert.equal(parseListMarker("- [x] done").continued, "- [ ] ")
    assert.equal(parseListMarker("- [X] done").continued, "- [ ] ")
  })

  it("continues a blockquote unchanged", () => {
    assert.deepEqual(parseListMarker("> quote"), { full: "> ", rest: "quote", continued: "> " })
  })

  it("keeps leading indentation in the continued marker", () => {
    assert.equal(parseListMarker("  - nested").continued, "  - ")
    assert.equal(parseListMarker("  3. nested").continued, "  4. ")
  })

  it("reports an empty rest for a bare marker, the removal signal", () => {
    for (const marker of ["- ", "* ", "1. ", "- [ ] ", "> "]) {
      const parsed = parseListMarker(marker)
      assert.ok(parsed, `expected ${marker} to parse`)
      assert.equal(parsed.rest.trim(), "", `expected empty rest for ${marker}`)
    }
  })

  it("returns null for a plain non-list line", () => {
    assert.equal(parseListMarker("just some text"), null)
    assert.equal(parseListMarker(""), null)
  })
})

describe("renumberFollowingLines", () => {
  it("returns null when the current line is the last one", () => {
    assert.equal(renumberFollowingLines("1. first", 8, "", 3), null)
  })

  it("returns null when no ordered line follows", () => {
    assert.equal(renumberFollowingLines("1. first\nplain", 8, "", 3), null)
    assert.equal(renumberFollowingLines("1. first\n- bullet", 8, "", 3), null)
  })

  it("renumbers consecutive same-indent followers", () => {
    const value = "1. first\n2. second\n3. third"
    assert.deepEqual(renumberFollowingLines(value, 8, "", 3), {
      end: value.length,
      text: "\n3. second\n4. third"
    })
  })

  it("stops at a blank line or plain text and leaves the rest untouched", () => {
    const value = "1. first\n2. second\n\n2. detached"
    assert.deepEqual(renumberFollowingLines(value, 8, "", 3), {
      end: 18,
      text: "\n3. second"
    })
  })

  it("stops the run at a deeper indent rather than renumbering across it", () => {
    const nested = "1. first\n2. second\n  2. nested\n2. back"
    assert.deepEqual(renumberFollowingLines(nested, 8, "", 3), {
      end: 18,
      text: "\n3. second"
    })
  })

  it("keeps each follower's own delimiter", () => {
    const value = "1) first\n2) second"
    assert.deepEqual(renumberFollowingLines(value, 8, "", 3), {
      end: value.length,
      text: "\n3) second"
    })
  })

  it("only touches the exact indent", () => {
    const value = "  1. first\n  2. second\n1. outer"
    assert.deepEqual(renumberFollowingLines(value, 10, "  ", 3), {
      end: 22,
      text: "\n  3. second"
    })
  })
})

describe("currentLine", () => {
  it("finds the line around a middle caret", () => {
    assert.deepEqual(currentLine("aaa\nbbb\nccc", 5), { lineStart: 4, lineEnd: 7, line: "bbb" })
  })

  it("finds the first line", () => {
    assert.deepEqual(currentLine("aaa\nbbb", 1), { lineStart: 0, lineEnd: 3, line: "aaa" })
  })

  it("finds the last line without a trailing newline", () => {
    assert.deepEqual(currentLine("aaa\nbbb", 6), { lineStart: 4, lineEnd: 7, line: "bbb" })
  })
})
