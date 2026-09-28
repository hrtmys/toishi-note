import { describe, it } from "node:test"
import assert from "node:assert/strict"

// Loaded dynamically so each case fails on its own while the module is missing.
const palette = await import("../../app/javascript/lib/palette_keys.js").catch(() => ({}))

const key = (k, mods = {}) => ({ key: k, ctrlKey: false, metaKey: false, shiftKey: false, altKey: false, isComposing: false, ...mods })

describe("isPaletteShortcut", () => {
  it("opens on Ctrl+p and Meta+p", () => {
    assert.equal(palette.isPaletteShortcut(key("p", { ctrlKey: true })), true)
    assert.equal(palette.isPaletteShortcut(key("p", { metaKey: true })), true)
  })

  it("does not open while composing or without a modifier", () => {
    assert.equal(palette.isPaletteShortcut(key("p", { ctrlKey: true, isComposing: true })), false)
    assert.equal(palette.isPaletteShortcut(key("p")), false)
  })
})

describe("paletteKeyAction", () => {
  it("maps navigation keys", () => {
    assert.equal(palette.paletteKeyAction(key("ArrowDown")), "next")
    assert.equal(palette.paletteKeyAction(key("ArrowUp")), "previous")
    assert.equal(palette.paletteKeyAction(key("Enter")), "visit")
    assert.equal(palette.paletteKeyAction(key("Escape")), "close")
  })

  it("lets Enter confirm IME conversion instead of visiting", () => {
    assert.equal(palette.paletteKeyAction(key("Enter", { isComposing: true })), null)
  })

  it("ignores other keys", () => {
    assert.equal(palette.paletteKeyAction(key("a")), null)
  })
})

describe("wrapIndex", () => {
  it("wraps past both ends", () => {
    assert.equal(palette.wrapIndex(1, 1, 3), 2)
    assert.equal(palette.wrapIndex(2, 1, 3), 0)
    assert.equal(palette.wrapIndex(0, -1, 3), 2)
  })

  it("treats no selection (-1) as the first item", () => {
    assert.equal(palette.wrapIndex(-1, 1, 3), 1)
  })

  it("returns -1 for an empty list", () => {
    assert.equal(palette.wrapIndex(0, 1, 0), -1)
  })
})
