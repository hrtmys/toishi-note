import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as outcome from "../../app/javascript/lib/submit_outcome.js"

const STREAM = "text/vnd.turbo-stream.html; charset=utf-8"
const HTML = "text/html; charset=utf-8"

describe("submitOutcome", () => {
  const cases = [
    ["a 200 turbo stream renders", { status: 200, redirected: false, contentType: STREAM }, "render"],
    ["a 200 non-stream (head :ok) is done", { status: 200, redirected: false, contentType: "text/html" }, "done"],
    ["a 422 fails", { status: 422, redirected: false, contentType: STREAM }, "fail"],
    ["a 404 fails", { status: 404, redirected: false, contentType: HTML }, "fail"],
    ["a 500 HTML page fails instead of rendering", { status: 500, redirected: false, contentType: HTML }, "fail"],
    ["a followed redirect to a 200 page is a visit", { status: 200, redirected: true, contentType: HTML }, "visit"],
    ["a redirect that ends on an error still fails", { status: 500, redirected: true, contentType: HTML }, "fail"]
  ]

  for (const [name, response, expected] of cases) {
    it(name, () => {
      assert.equal(outcome.submitOutcome(response), expected)
    })
  }
})
