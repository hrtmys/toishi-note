import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { SaveQueue } from "../../app/javascript/lib/save_queue.js"

// A send() whose responses the test releases by hand, so ordering is explicit.
function controlledSend() {
  const calls = []
  const send = (payload) => new Promise((resolve, reject) => calls.push({ payload, resolve, reject }))
  return { calls, send }
}

const tick = () => new Promise((resolve) => setImmediate(resolve))

describe("SaveQueue", () => {
  it("sends one save at a time, and the next one carries the version the first response returned", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 5, send })

    const first = queue.request("content", "a")
    const second = queue.request("title", "題名")
    await tick()
    assert.equal(calls.length, 1)
    assert.deepEqual(calls[0].payload, { field: "content", value: "a", version: 5 })

    calls[0].resolve({ status: 200, version: 6 })
    assert.equal(await first, "saved")
    await tick()
    assert.equal(calls.length, 2)
    assert.deepEqual(calls[1].payload, { field: "title", value: "題名", version: 6 })

    calls[1].resolve({ status: 200, version: 7 })
    assert.equal(await second, "saved")
    assert.equal(queue.version, 7)
  })

  it("coalesces waiting saves of one field into the latest value, and settles every request", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    const inFlight = queue.request("content", "- one")
    const waiting = ["- one\n- ", "- one\n- two", "- one\n- two\n- "].map((v) => queue.request("content", v))
    await tick()
    calls[0].resolve({ status: 200, version: 2 })
    await tick()

    assert.equal(calls.length, 2, "the three waiting saves go out as one")
    assert.deepEqual(calls[1].payload, { field: "content", value: "- one\n- two\n- ", version: 2 })
    calls[1].resolve({ status: 200, version: 3 })

    assert.deepEqual(await Promise.all([inFlight, ...waiting]), ["saved", "saved", "saved", "saved"])
  })

  it("never coalesces one field into another", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    queue.request("content", "x")
    queue.request("title", "t")
    queue.request("content", "xy")
    await tick()
    calls[0].resolve({ status: 200, version: 2 })
    await tick()
    calls[1].resolve({ status: 200, version: 3 })
    await tick()

    assert.deepEqual(calls.map((c) => [c.payload.field, c.payload.value]), [["content", "x"], ["title", "t"], ["content", "xy"]])
  })

  it("after a conflict, holds every later save instead of sending it with the other device's version", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 4, send })

    const conflicted = queue.request("content", "mine")
    const behind = queue.request("content", "mine, more")
    await tick()
    calls[0].resolve({ status: 409, version: 9 })
    assert.equal(await conflicted, "conflict")

    const typedAfter = queue.request("content", "mine, even more")
    await tick()
    assert.equal(calls.length, 1, "nothing is sent while the conflict is unresolved")
    assert.equal(queue.held, true)
    assert.equal(queue.hasUnsaved, true)
    assert.equal(queue.version, 4, "the other device's version is not adopted silently")

    queue.keepMine()
    await tick()
    assert.equal(calls.length, 2)
    assert.deepEqual(calls[1].payload, { field: "content", value: "mine, even more", version: 9 })
    calls[1].resolve({ status: 200, version: 10 })
    assert.deepEqual(await Promise.all([behind, typedAfter]), ["saved", "saved"])
    assert.equal(queue.held, false)
    assert.equal(queue.hasUnsaved, false)
  })

  it("discarding after a conflict drops the held saves and sends nothing", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    queue.request("content", "mine")
    await tick()
    calls[0].resolve({ status: 409, version: 2 })
    await tick()
    const held = queue.request("content", "mine again")

    queue.discard()
    assert.equal(await held, "discarded")
    await tick()
    assert.equal(calls.length, 1)
    assert.equal(queue.hasUnsaved, false)
  })

  it("a failed save (500 or network error) releases the queue for the next one", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    const serverError = queue.request("content", "a")
    const networkError = queue.request("title", "b")
    const after = queue.request("content", "c")
    await tick()
    calls[0].resolve({ status: 500, version: null })
    assert.equal(await serverError, "failed")
    await tick()
    calls[1].reject(new Error("offline"))
    assert.equal(await networkError, "failed")
    await tick()
    assert.deepEqual(calls[2].payload, { field: "content", value: "c", version: 1 })
    calls[2].resolve({ status: 200, version: 2 })
    assert.equal(await after, "saved")
  })

  it("never moves the known version backwards", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 8, send })

    queue.request("content", "a")
    await tick()
    calls[0].resolve({ status: 200, version: 3 })
    await tick()
    assert.equal(queue.version, 8)
  })

  it("reports unsaved work while a save is waiting or in flight, and none once everything landed", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })
    assert.equal(queue.hasUnsaved, false)

    const saved = queue.request("content", "a")
    assert.equal(queue.hasUnsaved, true)
    await tick()
    calls[0].resolve({ status: 200, version: 2 })
    await saved
    assert.equal(queue.hasUnsaved, false)
  })
})
