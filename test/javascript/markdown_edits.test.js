import { describe, it } from "node:test"
import assert from "node:assert/strict"

// Loaded dynamically so each case fails on its own while the module is missing.
const edits = await import("../../app/javascript/lib/markdown_edits.js").catch(() => ({}))

const key = (k, mods = {}) => ({ key: k, ctrlKey: false, metaKey: false, shiftKey: false, altKey: false, isComposing: false, ...mods })
const LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/

function run(value, edit) {
  return { value: edits.applyEdit(value, edit), selectionStart: edit.selectionStart, selectionEnd: edit.selectionEnd }
}

describe("applyEdit", () => {
  it("replaces [start, end) with the text", () => {
    assert.equal(edits.applyEdit("abcdef", { start: 1, end: 3, text: "X", selectionStart: 2, selectionEnd: 2 }), "aXdef")
  })
})

describe("shortcutCommand", () => {
  it("maps Ctrl/Meta+b to bold, including CapsLock's uppercase key", () => {
    assert.equal(edits.shortcutCommand(key("b", { ctrlKey: true })), "bold")
    assert.equal(edits.shortcutCommand(key("b", { metaKey: true })), "bold")
    assert.equal(edits.shortcutCommand(key("B", { ctrlKey: true })), "bold")
  })

  it("maps Ctrl+i to italic, Ctrl+k to link, Ctrl+Shift+k to deleteLine", () => {
    assert.equal(edits.shortcutCommand(key("i", { ctrlKey: true })), "italic")
    assert.equal(edits.shortcutCommand(key("k", { ctrlKey: true })), "link")
    assert.equal(edits.shortcutCommand(key("K", { ctrlKey: true, shiftKey: true })), "deleteLine")
    assert.equal(edits.shortcutCommand(key("k", { ctrlKey: true, shiftKey: true })), "deleteLine")
  })

  it("ignores Ctrl+Shift+b and AltGr (Ctrl+Alt) combinations", () => {
    assert.equal(edits.shortcutCommand(key("B", { ctrlKey: true, shiftKey: true })), null)
    assert.equal(edits.shortcutCommand(key("b", { ctrlKey: true, altKey: true })), null)
  })

  it("never fires during IME composition", () => {
    assert.equal(edits.shortcutCommand(key("b", { ctrlKey: true, isComposing: true })), null)
    assert.equal(edits.shortcutCommand(key("Process", { ctrlKey: true })), null)
  })

  it("ignores unmodified keys", () => {
    assert.equal(edits.shortcutCommand(key("b")), null)
  })
})

describe("wrapEdit", () => {
  it("wraps the full selection in bold with the caret after the closing fence", () => {
    assert.deepEqual(run("hello", edits.wrapEdit("hello", 0, 5, "**")), { value: "**hello**", selectionStart: 9, selectionEnd: 9 })
  })

  it("wraps a selection in the middle of a line", () => {
    assert.equal(run("a hello b", edits.wrapEdit("a hello b", 2, 7, "**")).value, "a **hello** b")
  })

  it("inserts an empty fence pair with the caret between them", () => {
    assert.deepEqual(run("", edits.wrapEdit("", 0, 0, "**")), { value: "****", selectionStart: 2, selectionEnd: 2 })
  })

  it("wraps Japanese text in italic", () => {
    assert.equal(run("こんにちは", edits.wrapEdit("こんにちは", 0, 5, "*")).value, "*こんにちは*")
  })

  it("keeps surrogate pairs intact", () => {
    const value = "𠮷野家"
    const result = run(value, edits.wrapEdit(value, 0, value.length, "**")).value
    assert.equal(result, "**𠮷野家**")
    assert.doesNotMatch(result, LONE_SURROGATE)
  })
})

describe("linkEdit", () => {
  it("wraps the selection as link text and selects the url placeholder", () => {
    const r = run("hello", edits.linkEdit("hello", 0, 5))
    assert.equal(r.value, "[hello](url)")
    assert.equal(r.value.slice(r.selectionStart, r.selectionEnd), "url")
  })

  it("inserts a placeholder link with the text placeholder selected", () => {
    const r = run("", edits.linkEdit("", 0, 0))
    assert.equal(r.value, "[text](url)")
    assert.equal(r.value.slice(r.selectionStart, r.selectionEnd), "text")
  })

  it("links Japanese text and still selects exactly the url", () => {
    const r = run("リンク", edits.linkEdit("リンク", 0, 3))
    assert.equal(r.value, "[リンク](url)")
    assert.equal(r.value.slice(r.selectionStart, r.selectionEnd), "url")
  })
})

describe("deleteLineEdit", () => {
  const text = "aaa\nbbb\nccc"

  it("removes a middle line together with its newline", () => {
    assert.equal(run(text, edits.deleteLineEdit(text, 5, 5)).value, "aaa\nccc")
  })

  it("removes the last line and the newline before it", () => {
    assert.equal(run(text, edits.deleteLineEdit(text, 9, 9)).value, "aaa\nbbb")
  })

  it("empties a single-line document", () => {
    assert.equal(run("abc", edits.deleteLineEdit("abc", 1, 1)).value, "")
  })

  it("removes every line the selection touches", () => {
    assert.equal(run(text, edits.deleteLineEdit(text, 1, 5)).value, "ccc")
  })

  it("handles an empty document", () => {
    assert.equal(run("", edits.deleteLineEdit("", 0, 0)).value, "")
  })
})

describe("urlPasteEdit", () => {
  it("turns a URL pasted over a selection into a link", () => {
    assert.equal(run("hello", edits.urlPasteEdit("hello", 0, 5, "https://example.com/note", false)).value,
      "[hello](https://example.com/note)")
    assert.equal(run("リンク", edits.urlPasteEdit("リンク", 0, 3, "https://example.com", false)).value,
      "[リンク](https://example.com)")
  })

  it("trims whitespace around the pasted URL", () => {
    assert.equal(run("hello", edits.urlPasteEdit("hello", 0, 5, "  https://x.y  ", false)).value, "[hello](https://x.y)")
  })

  it("rejects non-http schemes", () => {
    assert.equal(edits.urlPasteEdit("hello", 0, 5, "javascript:alert(1)", false), null)
    assert.equal(edits.urlPasteEdit("hello", 0, 5, "ftp://x", false), null)
  })

  it("rejects text that is not a single URL", () => {
    assert.equal(edits.urlPasteEdit("hello", 0, 5, "https://a b", false), null)
    assert.equal(edits.urlPasteEdit("hello", 0, 5, "https://a.b\nhttps://c.d", false), null)
  })

  it("leaves the paste alone without a selection or with an image", () => {
    assert.equal(edits.urlPasteEdit("hello", 5, 5, "https://example.com", false), null)
    assert.equal(edits.urlPasteEdit("hello", 0, 5, "https://example.com", true), null)
  })
})
