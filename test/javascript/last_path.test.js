// Unit tests for the not-yet-written lib/last_path.js. See
// navigation_controller.js for how storeLocation/connect will use this.
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { rememberablePath } from "../../app/javascript/lib/last_path.js"
// Namespace import so a missing export fails only the tests that use it.
import * as lastPath from "../../app/javascript/lib/last_path.js"

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

describe("restoreDecision", () => {
  const at = (path) => {
    const url = new URL(path, ORIGIN)
    return { href: url.href, origin: url.origin, pathname: url.pathname, search: url.search }
  }
  const NOTE = `${ORIGIN}/?notebook_id=1&folder_id=2&note_id=3`

  it("visits the stored note from the bare root", () => {
    assert.deepEqual(lastPath.restoreDecision(at("/"), NOTE), { store: NOTE, visitUrl: NOTE })
  })

  it("touches nothing on the new-note redirect, which carries a query", () => {
    assert.equal(lastPath.restoreDecision(at("/?notebook_id=1&note_id=2"), NOTE), null)
  })

  it("touches nothing off the root path", () => {
    assert.equal(lastPath.restoreDecision(at("/admin/users/new"), NOTE), null)
  })

  it("neither keeps nor visits a cross-origin stored URL", () => {
    assert.deepEqual(lastPath.restoreDecision(at("/"), "https://evil.example/?note_id=3"), { store: null, visitUrl: null })
  })

  it("does not visit when the stored URL is the current page", () => {
    assert.equal(lastPath.restoreDecision(at("/"), `${ORIGIN}/`).visitUrl, null)
  })

  it("drops a stored value that is not a URL", () => {
    assert.deepEqual(lastPath.restoreDecision(at("/"), "not a url"), { store: null, visitUrl: null })
  })

  it("strips mode params from the stored URL before visiting", () => {
    const decision = lastPath.restoreDecision(at("/"), `${ORIGIN}/?notebook_id=1&organize=true`)
    assert.deepEqual(decision, { store: `${ORIGIN}/?notebook_id=1`, visitUrl: `${ORIGIN}/?notebook_id=1` })
  })
})
