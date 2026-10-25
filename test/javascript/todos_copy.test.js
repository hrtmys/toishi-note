import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { copyableTodos } from "../../app/javascript/lib/todos_copy.js"

const MARKDOWN = "text/markdown; charset=utf-8"
const HTML = "text/html; charset=utf-8"

describe("copyableTodos", () => {
  const cases = [
    ["a 200 Markdown response is copyable", { status: 200, redirected: false, contentType: MARKDOWN }, true],
    ["a bare text/markdown content type is copyable", { status: 200, redirected: false, contentType: "text/markdown" }, true],
    ["a redirect to the sign-in page is not copyable", { status: 200, redirected: true, contentType: HTML }, false],
    ["a redirect is not copyable even with a Markdown content type", { status: 200, redirected: true, contentType: MARKDOWN }, false],
    ["a 200 HTML page is not copyable", { status: 200, redirected: false, contentType: HTML }, false],
    ["a 404 fails", { status: 404, redirected: false, contentType: HTML }, false],
    ["a 500 fails", { status: 500, redirected: false, contentType: MARKDOWN }, false],
    ["a missing content type fails", { status: 200, redirected: false, contentType: null }, false]
  ]

  for (const [name, response, expected] of cases) {
    it(name, () => {
      assert.equal(copyableTodos(response), expected)
    })
  }
})
