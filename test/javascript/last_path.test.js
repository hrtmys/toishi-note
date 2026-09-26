// Unit tests for the not-yet-written lib/last_path.js. See
// navigation_controller.js for how storeLocation/connect will use this.
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { rememberablePath } from "../../app/javascript/lib/last_path.js"

const ORIGIN = "https://example.com"

describe("rememberablePath", () => {
  it("keeps a plain note location unchanged", () => {
    const href = `${ORIGIN}/?notebook_id=1&folder_id=2&note_id=3`
    assert.equal(rememberablePath(href, ORIGIN), href)
  })

  it("strips organize, todos and view but keeps the rest in their original order", () => {
    const href = `${ORIGIN}/?notebook_id=1&organize=true&folder_id=2&todos=true&note_id=3&view=preview`
    assert.equal(rememberablePath(href, ORIGIN), `${ORIGIN}/?notebook_id=1&folder_id=2&note_id=3`)
  })

  it("drops each mode param individually", () => {
    assert.equal(rememberablePath(`${ORIGIN}/?notebook_id=1&organize=true`, ORIGIN), `${ORIGIN}/?notebook_id=1`)
    assert.equal(rememberablePath(`${ORIGIN}/?notebook_id=1&todos=true`, ORIGIN), `${ORIGIN}/?notebook_id=1`)
    assert.equal(rememberablePath(`${ORIGIN}/?notebook_id=1&view=preview`, ORIGIN), `${ORIGIN}/?notebook_id=1`)
  })

  it("collapses to the bare root when only mode params were present", () => {
    const href = `${ORIGIN}/?organize=true&todos=true&view=preview`
    assert.equal(rememberablePath(href, ORIGIN), `${ORIGIN}/`)
  })

  it("collapses a root with no query string at all to the bare root", () => {
    assert.equal(rememberablePath(`${ORIGIN}/`, ORIGIN), `${ORIGIN}/`)
  })

  it("returns null for a path other than the root", () => {
    assert.equal(rememberablePath(`${ORIGIN}/settings`, ORIGIN), null)
  })

  it("returns null for a different origin", () => {
    assert.equal(rememberablePath(`https://other.example/?notebook_id=1`, ORIGIN), null)
  })

  it("returns null for a string that isn't a URL", () => {
    assert.equal(rememberablePath("not a url", ORIGIN), null)
    assert.equal(rememberablePath("", ORIGIN), null)
  })
})
