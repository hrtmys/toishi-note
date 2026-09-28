import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { saveOutcome } from "../../app/javascript/lib/autosave.js"

describe("saveOutcome", () => {
  it("treats every 2xx as saved", () => {
    for (const status of [ 200, 201, 204, 299 ]) assert.equal(saveOutcome(status), "saved", String(status))
  })

  it("treats 409 as a conflict, not a plain failure", () => {
    assert.equal(saveOutcome(409), "conflict")
  })

  it("treats any other non-2xx as failed so it is never silent", () => {
    for (const status of [ 0, 199, 300, 302, 400, 401, 422, 500, 502 ]) assert.equal(saveOutcome(status), "failed", String(status))
  })
})
