import { describe, it, mock, beforeEach, afterEach } from "node:test"
import assert from "node:assert/strict"
import * as saveQueueLib from "../../app/javascript/lib/save_queue.js"

const { SaveQueue } = saveQueueLib

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

describe("SaveQueue debounce", () => {
  beforeEach(() => mock.timers.enable({ apis: [ "setTimeout" ] }))
  afterEach(() => mock.timers.reset())

  it("sends a scheduled value after 500 ms with the version current at send time", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 3, send })

    const settled = queue.schedule("content", "draft")
    mock.timers.tick(499)
    await tick()
    assert.equal(calls.length, 0)
    queue.adopt(4)
    mock.timers.tick(1)
    await tick()
    assert.deepEqual(calls.map((c) => c.payload), [ { field: "content", value: "draft", version: 4 } ])
    calls[0].resolve({ status: 200, version: 5 })
    assert.equal(await settled, "saved")
  })

  it("rescheduling sends once with the latest value; the replaced schedule settles superseded", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    const first = queue.schedule("content", "a")
    mock.timers.tick(300)
    const second = queue.schedule("content", "ab")
    mock.timers.tick(300)
    await tick()
    assert.equal(calls.length, 0, "the timer restarted")
    mock.timers.tick(200)
    await tick()
    assert.equal(calls.length, 1)
    assert.equal(calls[0].payload.value, "ab")
    calls[0].resolve({ status: 200, version: 2 })
    assert.deepEqual(await Promise.all([ first, second ]), [ "superseded", "saved" ])
  })

  it("request() for a scheduled field cancels its timer, so only one save goes out", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    const scheduled = queue.schedule("content", "typed")
    const requested = queue.request("content", "kept")
    assert.equal(await scheduled, "superseded")
    await tick()
    calls[0].resolve({ status: 200, version: 2 })
    assert.equal(await requested, "saved")
    mock.timers.tick(1000)
    await tick()
    assert.equal(calls.length, 1)
  })

  it("flush() sends a scheduled value at once, and it counts as unsaved until then", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    queue.schedule("content", "tail")
    assert.equal(queue.hasUnsaved, true)
    queue.flush()
    await tick()
    assert.deepEqual(calls.map((c) => c.payload), [ { field: "content", value: "tail", version: 1 } ])
  })

  it("postpone() stops the timer during composition but flush() still sends the confirmed value", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    queue.schedule("content", "日本語の")
    queue.postpone("content")
    mock.timers.tick(2000)
    await tick()
    assert.equal(calls.length, 0)
    assert.equal(queue.hasUnsaved, true)
    queue.flush()
    await tick()
    assert.equal(calls[0].payload.value, "日本語の")
  })

  it("discard() drops scheduled values so nothing is sent later", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })

    const scheduled = queue.schedule("content", "gone")
    queue.discard()
    assert.equal(await scheduled, "discarded")
    mock.timers.tick(1000)
    await tick()
    assert.equal(calls.length, 0)
    assert.equal(queue.hasUnsaved, false)
  })
})

let urlSeq = 0
const freshUrl = () => `/notes/${9000 + ++urlSeq}`

describe("one queue per note", () => {
  beforeEach(() => mock.timers.enable({ apis: [ "setTimeout" ] }))
  afterEach(() => mock.timers.reset())

  it("serializes saves from two page instances, the second carrying the version the first returned", async () => {
    const { calls, send } = controlledSend()
    const url = freshUrl()
    const queue = saveQueueLib.noteQueue(url, { version: 1, send })
    const pageA = {}
    const pageB = {}
    queue.attach(pageA, { version: 1 })
    assert.equal(saveQueueLib.noteQueue(url), queue)

    queue.schedule("content", "from A")
    queue.flush()
    queue.attach(pageB, { version: 1 })
    queue.schedule("title", "from B")
    queue.flush()
    await tick()
    assert.equal(calls.length, 1)
    calls[0].resolve({ status: 200, version: 2 })
    await tick()
    assert.deepEqual(calls[1].payload, { field: "title", value: "from B", version: 2 })
  })

  it("a hold survives the same wrapper reconnecting and is dropped when another instance attaches", async () => {
    const { calls, send } = controlledSend()
    const queue = saveQueueLib.noteQueue(freshUrl(), { version: 1, send })
    const page = {}
    queue.attach(page, { version: 1 })
    queue.request("content", "mine")
    await tick()
    calls[0].resolve({ status: 409, version: 2 })
    await tick()

    queue.detach(page)
    queue.attach(page, { version: 1 })
    assert.equal(queue.held, true)

    queue.attach({}, { version: 2 })
    assert.equal(queue.held, false)
    assert.equal(queue.hasUnsaved, false)
  })

  it("a higher-version attach is adopted without a hold", () => {
    const { send } = controlledSend()
    const queue = saveQueueLib.noteQueue(freshUrl(), { version: 4, send })
    queue.attach({}, { version: 6 })
    assert.equal(queue.held, false)
    assert.equal(queue.version, 6)
  })

  {
    it(`a lower-version render lowers what the next save sends, without holding`, async () => {
      const { calls, send } = controlledSend()
      const queue = saveQueueLib.noteQueue(freshUrl(), { version: 5, send })
      queue.attach({}, { version: 5 })

      queue.attach({}, { version: 3 })
      assert.equal(queue.held, false)
      queue.request("content", "typed on the older page")
      await tick()
      assert.equal(calls[0].payload.version, 3)
      calls[0].resolve({ status: 409, version: 6 })
      await tick()
      assert.equal(queue.held, true)
    })
  }

  it("a response to a save sent before the lowering doesn't raise the version; one sent after does", async () => {
    const { calls, send } = controlledSend()
    const queue = saveQueueLib.noteQueue(freshUrl(), { version: 5, send })
    queue.attach({}, { version: 5 })

    queue.request("content", "in flight")
    await tick()
    queue.attach({}, { version: 3 })
    calls[0].resolve({ status: 200, version: 6 })
    await tick()
    assert.equal(queue.version, 3)

    queue.request("content", "after lowering")
    await tick()
    assert.equal(calls[1].payload.version, 3)
    calls[1].resolve({ status: 200, version: 7 })
    await tick()
    assert.equal(queue.version, 7)
  })

  it("a value scheduled before the lowering is still sent and stays pending after its 409", async () => {
    const { calls, send } = controlledSend()
    const queue = saveQueueLib.noteQueue(freshUrl(), { version: 5, send })
    queue.attach({}, { version: 5 })

    const typed = queue.schedule("content", "typed before")
    queue.attach({}, { version: 3 })
    mock.timers.tick(500)
    await tick()
    assert.deepEqual(calls.map((c) => c.payload), [ { field: "content", value: "typed before", version: 3 } ])
    calls[0].resolve({ status: 409, version: 6 })
    assert.equal(await typed, "conflict")
    assert.equal(queue.held, true)
    assert.equal(queue.hasUnsaved, true)

    queue.keepMine()
    await tick()
    assert.deepEqual(calls[1].payload, { field: "content", value: "typed before", version: 6 })
  })

  it("while lowered, a toggle's version doesn't raise what the next save sends", async () => {
    const { calls, send } = controlledSend()
    const url = freshUrl()
    const queue = saveQueueLib.noteQueue(url, { version: 5, send })
    queue.attach({}, { version: 5 })
    queue.attach({}, { version: 3 })
    assert.equal(queue.lowered, true)

    saveQueueLib.findNoteQueue(url).adopt(6)
    queue.request("content", "x")
    await tick()
    assert.equal(calls[0].payload.version, 3)
  })

  it("a higher-version attach clears the lowered flag", () => {
    const { send } = controlledSend()
    const queue = saveQueueLib.noteQueue(freshUrl(), { version: 5, send })
    queue.attach({}, { version: 5 })
    queue.attach({}, { version: 3 })
    assert.equal(queue.lowered, true)
    queue.attach({}, { version: 8 })
    assert.equal(queue.lowered, false)
    assert.equal(queue.version, 8)
  })

  it("only a 2xx on a save sent after the lowering clears the flag", async () => {
    const { calls, send } = controlledSend()
    const queue = saveQueueLib.noteQueue(freshUrl(), { version: 5, send })
    queue.attach({}, { version: 5 })

    queue.request("content", "in flight")
    await tick()
    queue.attach({}, { version: 3 })
    calls[0].resolve({ status: 200, version: 6 })
    await tick()
    assert.equal(queue.lowered, true)

    queue.request("content", "after")
    await tick()
    calls[1].resolve({ status: 200, version: 7 })
    await tick()
    assert.equal(queue.lowered, false)
    queue.adopt(8)
    assert.equal(queue.version, 8)
  })

  it("ignores a toggle's version that skips one, so the next save sends the old version", async () => {
    const { calls, send } = controlledSend()
    const url = freshUrl()
    const queue = saveQueueLib.noteQueue(url, { version: 2, send })
    saveQueueLib.findNoteQueue(url).adopt(4)
    queue.request("content", "x")
    await tick()
    assert.equal(calls[0].payload.version, 2)
  })

  it("ignores a toggle's version while a save is in flight", async () => {
    const { calls, send } = controlledSend()
    const url = freshUrl()
    const queue = saveQueueLib.noteQueue(url, { version: 2, send })
    queue.request("content", "in flight")
    await tick()
    saveQueueLib.findNoteQueue(url).adopt(3)
    assert.equal(queue.version, 2)
    calls[0].resolve({ status: 409, version: 3 })
  })

  it("adopting a toggle's version raises the next save's version, ignores a lower one, and creates no queue", async () => {
    const { calls, send } = controlledSend()
    const url = freshUrl()
    const queue = saveQueueLib.noteQueue(url, { version: 2, send })
    saveQueueLib.findNoteQueue(url).adopt(3)
    saveQueueLib.findNoteQueue(url).adopt(1)
    queue.request("content", "after pin")
    await tick()
    assert.equal(calls[0].payload.version, 3)

    assert.equal(saveQueueLib.findNoteQueue(freshUrl()), undefined)
  })
})

describe("SaveQueue#waitForPending", () => {
  beforeEach(() => mock.timers.enable({ apis: [ "setTimeout" ] }))
  afterEach(() => mock.timers.reset())

  const watch = (promise) => {
    const state = { done: false }
    promise.then(() => { state.done = true })
    return state
  }

  it("resolves at once when nothing is pending", async () => {
    const { send } = controlledSend()
    const wait = watch(new SaveQueue({ version: 1, send }).waitForPending(5000))
    await tick()
    assert.equal(wait.done, true)
  })

  it("resolves once the saves pending at call time settle, not waiting for a value scheduled later", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })
    queue.schedule("content", "before")
    queue.flush()
    await tick()

    const wait = watch(queue.waitForPending(5000))
    queue.schedule("content", "typed during the wait")
    queue.flush()
    await tick()
    assert.equal(wait.done, false)

    calls[0].resolve({ status: 200, version: 2 })
    await tick()
    await tick()
    assert.equal(wait.done, true)
    assert.equal(queue.hasUnsaved, true, "the later value is still on its way")
  })

  it("resolves at the cap when a save hangs", async () => {
    const { send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })
    queue.request("content", "hangs")
    await tick()

    const wait = watch(queue.waitForPending(5000))
    mock.timers.tick(4999)
    await tick()
    assert.equal(wait.done, false)
    mock.timers.tick(1)
    await tick()
    assert.equal(wait.done, true)
  })

  it("ends the wait when a pending save is held after a 409, without running to the cap", async () => {
    const { calls, send } = controlledSend()
    const queue = new SaveQueue({ version: 1, send })
    queue.request("content", "mine")
    await tick()

    const wait = watch(queue.waitForPending(5000))
    calls[0].resolve({ status: 409, version: 2 })
    await tick()
    await tick()
    assert.equal(queue.held, true)
    assert.equal(wait.done, true)
  })
})
