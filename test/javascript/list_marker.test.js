// Unit tests for lib/list_marker.js.
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import {
  currentLine, enterAction, parseListMarker, tabAction
} from "../../app/javascript/lib/list_marker.js"

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
    for (const marker of ["- ", "* ", "+ ", "1. ", "- [ ] ", "> "]) {
      const parsed = parseListMarker(marker)
      assert.ok(parsed, `expected ${marker} to parse`)
      assert.equal(parsed.rest.trim(), "", `expected empty rest for ${marker}`)
    }
  })

  it("returns null for a plain non-list line", () => {
    assert.equal(parseListMarker("just some text"), null)
    assert.equal(parseListMarker(""), null)
  })

  it("returns null for a line indented with a full-width space", () => {
    assert.equal(parseListMarker("　- a"), null)
  })

  it("accepts a full-width gap after a marker and continues it with an ASCII space", () => {
    assert.equal(parseListMarker("-　a").continued, "- ")
  })

  it("keeps the gap length in the continued marker, mapping each gap character to one space", () => {
    assert.equal(parseListMarker("-\u00A0\u3000\u00A0a").continued, "-   ")
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

const enter = (value, caret, extra = {}) => enterAction({
  value, selectionStart: caret, selectionEnd: caret,
  isComposing: false, shiftKey: false, ctrlKey: false, metaKey: false, altKey: false, ...extra
})
const tab = (value, caret, extra = {}) => tabAction({
  value, selectionStart: caret, selectionEnd: caret, shiftKey: false, isComposing: false, ...extra
})
const apply = (value, edit) => value.slice(0, edit.start) + edit.text + value.slice(edit.end)

// "|" marks the caret in a before/after document; it is stripped before use.
const caretAt = (text) => ({ value: text.replace("|", ""), caret: text.indexOf("|") })
const expectEnter = (before, after) => {
  const start = caretAt(before)
  const expected = caretAt(after)
  const result = enter(start.value, start.caret)
  assert.ok(result?.edit, `no edit for ${JSON.stringify(before)}`)
  const { edit } = result
  assert.deepEqual(
    { before, value: apply(start.value, edit), selectionStart: edit.selectionStart, selectionEnd: edit.selectionEnd },
    { before, value: expected.value, selectionStart: expected.caret, selectionEnd: expected.caret }
  )
}
const expectNoEnter = (before, extra) => {
  const { value, caret } = caretAt(before)
  assert.equal(enter(value, caret, extra), null, before)
}

describe("enterAction", () => {
  it("continues a bullet", () => {
    const result = enter("- first", 7)
    assert.equal(apply("- first", result.edit), "- first\n- ")
    assert.equal(result.edit.selectionStart, 10)
    assert.equal(result.edit.selectionEnd, 10)
  })

  it("leaves the following ordered items' numbers alone", () => {
    const value = "1. first\n2. second"
    const { edit } = enter(value, 8)
    assert.equal(apply(value, edit), "1. first\n2. \n2. second")
    assert.equal(edit.selectionStart, "1. first\n2. ".length)
  })

  it("inserts the next number at the caret without renumbering the items below", () => {
    expectEnter("1. a|\n2. b\n3. c", "1. a\n2. |\n2. b\n3. c")
  })

  it("does not rewrite a 400-item ordered list when Enter is pressed on its first item", () => {
    const value = Array.from({ length: 400 }, (_, i) => `${i + 1}. item`).join("\n")
    const caret = "1. item".length
    const { edit } = enter(value, caret)
    assert.equal(edit.start, caret)
    assert.equal(edit.end, caret)
    assert.equal(edit.text.split("\n").length - 1, 1)
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
    assert.equal(enterAction({
      value: "- first", selectionStart: 2, selectionEnd: 7,
      isComposing: false, shiftKey: false, ctrlKey: false, metaKey: false, altKey: false
    }), null)
  })

  it("ignores modified Enter and IME confirmation", () => {
    for (const mod of ["shiftKey", "ctrlKey", "metaKey", "altKey", "isComposing"]) {
      assert.equal(enter("- first", 7, { [mod]: true }), null, mod)
    }
  })

  it("exits an empty bullet, ordered, or task marker, leaving a blank line", () => {
    expectEnter("- a\n- |", "- a\n\n|")
    expectEnter("* a\n* |", "* a\n\n|")
    expectEnter("1. a\n2. |", "1. a\n\n|")
    expectEnter("1) a\n2) |", "1) a\n\n|")
    expectEnter("- [ ] a\n- [ ] |", "- [ ] a\n\n|")
    expectEnter("- [x] a\n- [x] |", "- [x] a\n\n|")
  })

  it("exits an empty blockquote marker, alone or as an item inside a quote", () => {
    expectEnter("> q\n> |", "> q\n\n|")
    expectEnter("> q\n>|", "> q\n\n|")
    expectEnter("> - a\n> |", "> - a\n\n|")
  })

  it("adds the blank line only after a non-blank line", () => {
    expectEnter("* |", "|")
    expectEnter("para\n- |", "para\n\n|")
    expectEnter("- a\n\n- |", "- a\n\n|")
  })

  it("exits mid-list, with trailing spaces, or with the caret before the marker", () => {
    expectEnter("- a\n-   |", "- a\n\n|")
    expectEnter("- a\n|- ", "- a\n\n|")
    expectEnter("- a\n- |\n- c", "- a\n\n|\n- c")
  })

  it("treats + as a list marker", () => {
    expectEnter("+ a\n+ |", "+ a\n\n|")
    expectEnter("+ a|", "+ a\n+ |")
    expectEnter("+ [x] a|", "+ [x] a\n+ [ ] |")
  })

  it("makes an empty nested item the parent's next item, leaving the items below it alone", () => {
    expectEnter("- a\n  - |", "- a\n- |")
    expectEnter("- a\n  - b\n    - |", "- a\n  - b\n  - |")
    expectEnter("1. a\n   - |\n2. b", "1. a\n2. |\n2. b")
    expectEnter("- [x] a\n  - [ ] |", "- [x] a\n- [ ] |")
    expectEnter("* a\n  1. |", "* a\n* |")
    expectEnter("- a\n\n  - b\n  - |", "- a\n\n  - b\n- |")
    expectEnter("- a\n\t- |", "- a\n- |")
    expectEnter("- a\n  - |\n  - c", "- a\n- |\n  - c")
  })

  it("exits an indented line that has no list item above it", () => {
    expectEnter("para\n  - |", "para\n\n|")
    expectEnter("> a\n  - |", "> a\n\n|")
    expectEnter("para\n  > |", "para\n\n|")
  })

  it("leaves a quote inside a list item and keeps the item's indent", () => {
    expectEnter("- a\n  > q\n  > |", "- a\n  > q\n\n  |")
  })

  it("returns null for IME composition and Shift+Enter on an empty marker", () => {
    expectNoEnter("- a\n- |", { isComposing: true })
    expectNoEnter("- a\n  - |", { isComposing: true })
    expectNoEnter("- a\n- |", { shiftKey: true })
  })
})

const expectTab = (before, after, extra = {}) => {
  const start = caretAt(before)
  const expected = caretAt(after)
  const result = tab(start.value, start.caret, extra)
  assert.ok(result?.edit, `no edit for ${JSON.stringify(before)}`)
  const { edit } = result
  assert.deepEqual(
    { before, value: apply(start.value, edit), selectionStart: edit.selectionStart, selectionEnd: edit.selectionEnd },
    { before, value: expected.value, selectionStart: expected.caret, selectionEnd: expected.caret }
  )
}
const expectTabSwallowed = (before, extra = {}) => {
  const { value, caret } = caretAt(before)
  assert.deepEqual(tab(value, caret, extra), { edit: null }, before)
}

describe("tabAction", () => {
  it("indents a list line to the next level under its parent", () => {
    expectTab("- a\n- |b", "- a\n  - |b")
    expectTab("- [ ] a\n- [ ] |b", "- [ ] a\n  - [ ] |b")
    expectTab("- a\n\n- |b", "- a\n\n  - |b")
    expectTab("- a\n  - b\n- |c", "- a\n  - b\n  - |c")
    expectTab("- a\n- b|c", "- a\n  - b|c")
  })

  it("renumbers an ordered item only when it becomes the first at its new level", () => {
    expectTab("1. a\n2. |b", "1. a\n   1. |b")
    expectTab("10. a\n11. |b", "10. a\n    1. |b")
    expectTab("1. a\n   1. b\n2. |c", "1. a\n   1. b\n   2. |c")
  })

  it("swallows Tab when no level is deeper, and Tab or Shift+Tab on a quote line", () => {
    expectTabSwallowed("- a\n  - |b")
    expectTabSwallowed("- |a")
    expectTabSwallowed("# H\n- |a")
    expectTabSwallowed("para\n- |a")
    expectTabSwallowed("- a\n  - b\n\t- |c")
    expectTabSwallowed("> - a\n> - |b")
    expectTabSwallowed("> - a\n> - |b", { shiftKey: true })
  })

  it("moves a list line to the previous level on Shift+Tab", () => {
    expectTab("- a\n  - |b", "- a\n- |b", { shiftKey: true })
    expectTab("1. a\n   - |b", "1. a\n- |b", { shiftKey: true })
    expectTab("- a\n  - b\n    - |c", "- a\n  - b\n  - |c", { shiftKey: true })
    expectTabSwallowed("- |a", { shiftKey: true })
    expectTab("- a\n\t- |b", "- a\n  - |b", { shiftKey: true })
  })

  it("skips indented continuation text when finding the levels above", () => {
    expectTab("- a\n  more\n- |b", "- a\n  more\n  - |b")
    expectTab("-     a\n- |b", "-     a\n  - |b")
  })

  it("leaves Tab on non-list text and during IME composition to the browser", () => {
    const plain = caretAt("para|")
    assert.equal(tab(plain.value, plain.caret), null)
    const composing = caretAt("- a\n- |b")
    assert.equal(tab(composing.value, composing.caret, { isComposing: true }), null)
  })

  it("swallows Shift+Tab on an unindented list line", () => {
    assert.deepEqual(tab("- a", 3, { shiftKey: true }), { edit: null })
  })

  it("leaves Tab on plain lines to the browser", () => {
    assert.equal(tab("hello", 5), null)
  })
})

describe("enterAction with full-width and no-break gaps", () => {
  it("continues a full-width-gapped bullet with an ASCII space and rewrites the gap", () => {
    expectEnter("-　a|", "- a\n- |")
  })

  it("continues an ordered item unchanged", () => {
    expectEnter("1.\u00A0a|", "1. a\n2. |")
  })

  it("continues a task item with a full-width gap after the box", () => {
    expectEnter("- [ ]　a|", "- [ ] a\n- [ ] |")
  })

  it("keeps the gap width when continuing a bullet with two full-width spaces", () => {
    expectEnter("-　　a|", "-  a\n-  |")
  })

  it("exits a bullet whose only gap is full-width", () => {
    expectEnter("-　|", "|")
  })

  it("leaves a full-width-indented list line to the browser", () => {
    expectNoEnter("　- a|")
  })

  it("does not nest a full-width-indented line under the item above it", () => {
    expectNoEnter("- a\n　- b|")
  })

  it("leaves a Japanese middle-dot bullet to the browser", () => {
    expectNoEnter("・a|")
  })

  it("continues a task item with full-width gaps on both sides of the box", () => {
    expectEnter("-　[ ]　x|", "- [ ] x\n- [ ] |")
  })
})
