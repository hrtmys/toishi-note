import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { DEFAULT_SORT, nextSortState, sortNoteEntries } from "../../app/javascript/lib/note_sort.js"

const entry = (ref, fields = {}) => ({ pinned: false, title: ref, updatedAt: 0, createdAt: 0, ref, ...fields })
const refs = (entries) => entries.map((e) => e.ref)

describe("nextSortState", () => {
  it("defaults to updated, newest first", () => {
    assert.deepEqual(DEFAULT_SORT, { mode: "updated", direction: "desc" })
  })

  it("opens title ascending, then flips on a second click", () => {
    const first = nextSortState(DEFAULT_SORT, "title")
    assert.deepEqual(first, { mode: "title", direction: "asc" })
    assert.deepEqual(nextSortState(first, "title"), { mode: "title", direction: "desc" })
  })

  it("opens a date mode descending, even coming from title ascending", () => {
    assert.deepEqual(nextSortState({ mode: "title", direction: "asc" }, "created"), { mode: "created", direction: "desc" })
  })

  it("flips the direction when the active mode is clicked again", () => {
    assert.deepEqual(nextSortState(DEFAULT_SORT, "updated"), { mode: "updated", direction: "asc" })
  })
})

describe("sortNoteEntries", () => {
  const entries = [
    entry("old", { updatedAt: 1, createdAt: 30, title: "b" }),
    entry("pinOld", { pinned: true, updatedAt: 2, createdAt: 10, title: "z" }),
    entry("new", { updatedAt: 9, createdAt: 20, title: "a" }),
    entry("pinNew", { pinned: true, updatedAt: 8, createdAt: 40, title: "y" })
  ]

  it("sorts by updated desc with pinned first, pinned ones sorted among themselves", () => {
    assert.deepEqual(refs(sortNoteEntries(entries, DEFAULT_SORT)), [ "pinNew", "pinOld", "new", "old" ])
  })

  it("keeps pinned first in every mode and direction", () => {
    assert.deepEqual(refs(sortNoteEntries(entries, { mode: "updated", direction: "asc" })), [ "pinOld", "pinNew", "old", "new" ])
    assert.deepEqual(refs(sortNoteEntries(entries, { mode: "created", direction: "asc" })), [ "pinOld", "pinNew", "new", "old" ])
    assert.deepEqual(refs(sortNoteEntries(entries, { mode: "title", direction: "asc" })), [ "pinNew", "pinOld", "new", "old" ])
    assert.deepEqual(refs(sortNoteEntries(entries, { mode: "title", direction: "desc" })), [ "pinOld", "pinNew", "old", "new" ])
  })

  it("puts an empty title first when ascending", () => {
    const list = [ entry("a", { title: "a" }), entry("blank", { title: "" }) ]
    assert.deepEqual(refs(sortNoteEntries(list, { mode: "title", direction: "asc" })), [ "blank", "a" ])
  })

  it("returns a new array and leaves the input order alone", () => {
    const input = [ ...entries ]
    const result = sortNoteEntries(input, DEFAULT_SORT)
    assert.notEqual(result, input)
    assert.deepEqual(refs(input), refs(entries))
  })
})
