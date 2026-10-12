import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as autosave from "../../app/javascript/lib/autosave.js"

const { saveOutcome } = autosave

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

describe("keepaliveEligible", () => {
  it("fits a body within the 64 KiB per-document keepalive budget, counted in UTF-8 bytes", () => {
    assert.equal(autosave.keepaliveEligible("a".repeat(65536), 0), true)
    assert.equal(autosave.keepaliveEligible("a".repeat(65537), 0), false)
    assert.equal(autosave.keepaliveEligible("あ".repeat(21846), 0), false)
    assert.equal(autosave.keepaliveEligible("a".repeat(1000), 65000), false)
    assert.equal(autosave.keepaliveEligible("a".repeat(1000), 64536), true)
  })
})

describe("leaveDecision", () => {
  const queue = (overrides) => ({ held: false, wrapperConnected: true, inFlight: false, waiting: false, ...overrides })
  const rows = [
    [ "idle", { queues: [ queue() ] }, "leave" ],
    [ "a value waiting behind an in-flight save", { queues: [ queue({ inFlight: true, waiting: true }) ] }, "warn" ],
    [ "a save in flight sent without keepalive", { queues: [ queue({ inFlight: true, inFlightKeepalive: false }) ] }, "warn" ],
    [ "a lowered queue, whose flush would conflict after unload", { queues: [ queue({ lowered: true }) ] }, "warn" ],
    [ "held with its wrapper connected", { queues: [ queue({ held: true }) ] }, "warn" ],
    [ "held with no wrapper connected", { queues: [ queue({ held: true, wrapperConnected: false }) ] }, "leave" ],
  ]
  for (const [ name, state, expected ] of rows) {
    it(name, () => assert.equal(autosave.leaveDecision(state), expected))
  }
})

describe("titleSyncDecision", () => {
  const base = { ownUrl: "/notes/1", noteUrl: "/notes/1", incoming: "New", current: "Old", lastServerValue: "Old", composing: false, titleSaveActive: false, focused: false }
  const decide = (overrides) => autosave.titleSyncDecision({ ...base, ...overrides })

  it("applies to an untouched, unfocused field", () => assert.equal(decide({}), "apply"))
  it("ignores another note's value", () => assert.equal(decide({ noteUrl: "/notes/2" }), "ignore"))
  it("does nothing when the value is already shown", () => assert.equal(decide({ incoming: "Old" }), "noop"))
  it("treats a blanked and saved title as clean", () => assert.equal(decide({ current: "", lastServerValue: "" }), "apply"))
  it("defers while focused", () => assert.equal(decide({ focused: true }), "defer"))
  it("skips when the user has edited the title", () => assert.equal(decide({ current: "Mine" }), "skip"))
  it("skips while composing", () => assert.equal(decide({ composing: true }), "skip"))
  it("skips while a title save is scheduled or in flight", () => assert.equal(decide({ titleSaveActive: true }), "skip"))
  it("on blur, applies a deferred value only while the field is still clean", () => {
    assert.equal(decide({ focused: false }), "apply")
    assert.equal(decide({ focused: false, current: "Typed then left" }), "skip")
  })
})

describe("visitDecision", () => {
  const unsaved = { held: false, hasUnsaved: true }
  const base = { method: "GET", kind: "drive", frameHasNoteWrapper: false, queues: [ unsaved ], prefetchAttached: false, prefetchCounter: null, saveCounter: 0 }
  const decide = (overrides) => autosave.visitDecision({ ...base, ...overrides })

  it("pauses and flushes a Drive visit while a non-held queue has unsaved work", () => {
    assert.deepEqual(decide({}), { pause: true, flush: true, dropPrefetch: false })
  })
  it("never pauses or flushes a prefetch", () => {
    const d = decide({ kind: "prefetch" })
    assert.equal(d.pause, false)
    assert.equal(d.flush, false)
  })
  it("does not pause for a held-only queue", () => assert.equal(decide({ queues: [ { held: true, hasUnsaved: true } ] }).pause, false))
  it("leaves non-GET requests alone", () => assert.equal(decide({ method: "POST" }).pause, false))
  it("leaves a frame without a note wrapper alone", () => assert.equal(decide({ kind: "frame", frameHasNoteWrapper: false }).pause, false))
  it("pauses a frame that contains a note wrapper", () => assert.equal(decide({ kind: "frame", frameHasNoteWrapper: true }).pause, true))
  it("drops a reused prefetch when a save happened since it was taken or work was unsaved, and keeps it otherwise", () => {
    const idle = [ { held: false, hasUnsaved: false } ]
    assert.equal(decide({ queues: idle, prefetchAttached: true, prefetchCounter: 1, saveCounter: 2 }).dropPrefetch, true)
    assert.equal(decide({ prefetchAttached: true, prefetchCounter: 2, saveCounter: 2 }).dropPrefetch, true)
    assert.equal(decide({ queues: idle, prefetchAttached: true, prefetchCounter: 2, saveCounter: 2 }).dropPrefetch, false)
  })
})

describe("conflictRoute", () => {
  it("shows the banner when the wrapper is connected and no visit is paused", () => {
    assert.equal(autosave.conflictRoute({ wrapperConnected: true, visitPaused: false, title: "Plan", placeholder: "Untitled" }).action, "banner")
  })
  it("discards and toasts after the next load while a visit is paused", () => {
    assert.deepEqual(autosave.conflictRoute({ wrapperConnected: true, visitPaused: true, title: "Plan", placeholder: "Untitled" }), { action: "toast_after_load", discard: true, title: "Plan" })
  })
  it("discards and toasts now when no wrapper is connected, naming the placeholder for a blank title", () => {
    assert.deepEqual(autosave.conflictRoute({ wrapperConnected: false, visitPaused: false, title: "", placeholder: "無題" }), { action: "toast_now", discard: true, title: "無題" })
  })
})

describe("unloadListenerNeeded", () => {
  const q = (overrides) => ({ hasUnsaved: false, held: false, wrapperConnected: true, ...overrides })
  const rows = [
    [ "no queues", [], false ],
    [ "idle queues", [ q(), q({ wrapperConnected: false }) ], false ],
    [ "unsaved values", [ q({ hasUnsaved: true }) ], true ],
    [ "unsaved values on a page that left", [ q({ hasUnsaved: true, wrapperConnected: false }) ], true ],
    [ "held with its wrapper connected", [ q({ hasUnsaved: true, held: true }) ], true ],
    [ "held with its wrapper gone", [ q({ hasUnsaved: true, held: true, wrapperConnected: false }) ], false ],
    [ "a held, gone note next to an unsaved one", [ q({ hasUnsaved: true, held: true, wrapperConnected: false }), q({ hasUnsaved: true }) ], true ]
  ]
  for (const [ name, queues, expected ] of rows) {
    it(name, () => assert.equal(autosave.unloadListenerNeeded(queues), expected))
  }
})
