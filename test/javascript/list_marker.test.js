// Unit tests for lib/list_marker.js. Mirrors the MARKERS matrix
// from list_continuation_test.rb (now dash-wiring only).
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { currentLine, parseListMarker, renumberFollowingLines } from "../../app/javascript/lib/list_marker.js"
import * as listMarker from "../../app/javascript/lib/list_marker.js"

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

// Namespace access so the cases above keep running while these exports are missing.
const enter = (value, caret, extra = {}) => listMarker.enterAction({
  value, selectionStart: caret, selectionEnd: caret, armedMarker: null,
  isComposing: false, shiftKey: false, ctrlKey: false, metaKey: false, altKey: false, ...extra
})
const tab = (value, caret, extra = {}) => listMarker.tabAction({
  value, selectionStart: caret, selectionEnd: caret, shiftKey: false, isComposing: false, ...extra
})
const apply = (value, edit) => value.slice(0, edit.start) + edit.text + value.slice(edit.end)

describe("enterAction", () => {
  it("continues a bullet and arms the inserted marker", () => {
    const result = enter("- first", 7)
    assert.equal(apply("- first", result.edit), "- first\n- ")
    assert.equal(result.edit.selectionStart, 10)
    assert.equal(result.edit.selectionEnd, 10)
    assert.equal(result.armedMarker, "- ")
  })

  it("removes an armed, still-empty marker line and disarms", () => {
    const value = "- first\n- "
    const result = enter(value, 10, { armedMarker: "- " })
    assert.equal(apply(value, result.edit), "- first\n")
    assert.equal(result.edit.selectionStart, 8)
    assert.equal(result.armedMarker, null)
  })

  it("continues a typed-in empty marker that was never armed", () => {
    assert.equal(apply("* ", enter("* ", 2).edit), "* \n* ")
  })

  it("renumbers the following ordered items", () => {
    const value = "1. first\n2. second"
    const { edit } = enter(value, 8)
    assert.equal(apply(value, edit), "1. first\n2. \n3. second")
    assert.equal(edit.selectionStart, "1. first\n2. ".length)
  })

  it("continues each marker style", () => {
    assert.equal(apply("1) a", enter("1) a", 4).edit), "1) a\n2) ")
    assert.equal(apply("- [x] done", enter("- [x] done", 10).edit), "- [x] done\n- [ ] ")
    assert.equal(apply("> q", enter("> q", 3).edit), "> q\n> ")
    assert.equal(apply("  - a", enter("  - a", 5).edit), "  - a\n  - ")
    assert.equal(apply("- 項目", enter("- 項目", 4).edit), "- 項目\n- ")
  })

  it("leaves plain lines and selections to the browser", () => {
    assert.equal(enter("hello", 5), null)
    assert.equal(listMarker.enterAction({
      value: "- first", selectionStart: 2, selectionEnd: 7, armedMarker: null,
      isComposing: false, shiftKey: false, ctrlKey: false, metaKey: false, altKey: false
    }), null)
  })

  it("ignores modified Enter and IME confirmation", () => {
    for (const mod of ["shiftKey", "ctrlKey", "metaKey", "altKey", "isComposing"]) {
      assert.equal(enter("- first", 7, { [mod]: true }), null, mod)
    }
  })
})

describe("disarmsContinuation", () => {
  it("disarms on typed characters and deletions", () => {
    for (const key of ["a", "あ", "Backspace", "Delete"]) assert.equal(listMarker.disarmsContinuation(key), true, key)
  })

  it("keeps the marker armed on navigation and modifiers", () => {
    for (const key of ["ArrowLeft", "Shift", "Enter"]) assert.equal(listMarker.disarmsContinuation(key), false, key)
  })
})

describe("tabAction", () => {
  it("indents a list line by two spaces and shifts the caret", () => {
    const { edit } = tab("- a", 3)
    assert.equal(apply("- a", edit), "  - a")
    assert.equal(edit.selectionStart, 5)
    assert.equal(edit.selectionEnd, 5)
  })

  it("outdents two spaces or a tab on Shift+Tab", () => {
    assert.equal(apply("  - a", tab("  - a", 5, { shiftKey: true }).edit), "- a")
    assert.equal(apply("\t- a", tab("\t- a", 4, { shiftKey: true }).edit), "- a")
  })

  it("swallows Shift+Tab on an unindented list line", () => {
    assert.deepEqual(tab("- a", 3, { shiftKey: true }), { edit: null })
  })

  it("leaves Tab on plain lines to the browser", () => {
    assert.equal(tab("hello", 5), null)
  })
})
