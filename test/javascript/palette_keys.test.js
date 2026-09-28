import { describe, it } from "node:test"
import assert from "node:assert/strict"

import { isPaletteShortcut, paletteKeyAction, wrapIndex } from "../../app/javascript/lib/palette_keys.js"

const key = (k, mods = {}) => ({ key: k, ctrlKey: false, metaKey: false, shiftKey: false, altKey: false, isComposing: false, ...mods })

describe("isPaletteShortcut", () => {
  it("opens on Ctrl+p and Meta+p", () => {
    assert.equal(isPaletteShortcut(key("p", { ctrlKey: true })), true)
    assert.equal(isPaletteShortcut(key("p", { metaKey: true })), true)
  })

  it("does not open while composing or without a modifier", () => {
    assert.equal(isPaletteShortcut(key("p", { ctrlKey: true, isComposing: true })), false)
    assert.equal(isPaletteShortcut(key("p")), false)
  })
})

describe("paletteKeyAction", () => {
  it("maps navigation keys", () => {
    assert.equal(paletteKeyAction(key("ArrowDown")), "next")
    assert.equal(paletteKeyAction(key("ArrowUp")), "previous")
    assert.equal(paletteKeyAction(key("Enter")), "visit")
    assert.equal(paletteKeyAction(key("Escape")), "close")
  })

  it("lets Enter confirm IME conversion instead of visiting", () => {
    assert.equal(paletteKeyAction(key("Enter", { isComposing: true })), null)
  })

  it("ignores other keys", () => {
    assert.equal(paletteKeyAction(key("a")), null)
  })
})

describe("wrapIndex", () => {
  it("wraps past both ends", () => {
    assert.equal(wrapIndex(1, 1, 3), 2)
    assert.equal(wrapIndex(2, 1, 3), 0)
    assert.equal(wrapIndex(0, -1, 3), 2)
  })

  it("treats no selection (-1) as the first item", () => {
    assert.equal(wrapIndex(-1, 1, 3), 1)
  })

  it("returns -1 for an empty list", () => {
    assert.equal(wrapIndex(0, 1, 0), -1)
  })
})
