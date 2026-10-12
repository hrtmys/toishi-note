import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as serialQueue from "../../app/javascript/lib/serial_queue.js"

function deferred() {
  let resolve, reject
  const promise = new Promise((res, rej) => { resolve = res; reject = rej })
  return { promise, resolve, reject }
}

const tick = () => new Promise((resolve) => setImmediate(resolve))

describe("createSerialQueue", () => {
  it("starts the next task only after the previous one settles, in enqueue order", async () => {
    const queue = serialQueue.createSerialQueue()
    const started = []
    const first = deferred()
    const second = deferred()

    const a = queue.enqueue(() => { started.push("a"); return first.promise })
    const b = queue.enqueue(() => { started.push("b"); return second.promise })
    await tick()
    assert.deepEqual(started, ["a"])

    first.resolve("A")
    await a
    await tick()
    assert.deepEqual(started, ["a", "b"])

    second.resolve("B")
    await b
  })

  it("runs two tasks enqueued in the same tick, in order", async () => {
    const queue = serialQueue.createSerialQueue()
    const ran = []
    await Promise.all([
      queue.enqueue(async () => { ran.push(1) }),
      queue.enqueue(async () => { ran.push(2) })
    ])
    assert.deepEqual(ran, [1, 2])
  })

  it("rejects only the failing task's caller and still runs the next task", async () => {
    const queue = serialQueue.createSerialQueue()
    const failing = queue.enqueue(async () => { throw new Error("network") })
    const next = queue.enqueue(async () => "ok")

    await assert.rejects(failing, /network/)
    assert.equal(await next, "ok")
  })

  it("starts a task enqueued after the queue has drained straight away", async () => {
    const queue = serialQueue.createSerialQueue()
    await queue.enqueue(async () => "first")

    let started = false
    const later = queue.enqueue(async () => { started = true; return "later" })
    await tick()
    assert.equal(started, true)
    assert.equal(await later, "later")
  })

  it("resolves each caller with its own task's value", async () => {
    const queue = serialQueue.createSerialQueue()
    const slow = deferred()
    const a = queue.enqueue(() => slow.promise)
    const b = queue.enqueue(async () => "B")
    slow.resolve("A")
    assert.deepEqual(await Promise.all([a, b]), ["A", "B"])
  })
})
