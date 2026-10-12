// The Markdown grammar mirrors TodoPaste (app/models/todo_paste.rb); the
// preview only creates items, so a removal marker is rejected, never honoured.
import { describe, it } from "node:test"
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"
import { previewBulkEntries, parseTaskTags } from "../../app/javascript/lib/bulk_todo_preview.js"

const tasks = (result) => result.entries.filter((e) => e.kind === "task")

// Shared with test/models/todo_paste_test.rb: both parsers must produce these rows.
const sharedFixture = JSON.parse(readFileSync(new URL("../shared/todo_paste_cases.json", import.meta.url), "utf8"))
const sharedCases = sharedFixture.tag_cases

describe("parseTaskTags: shared cases with TodoPaste", () => {
  for (const row of sharedCases) {
    it(`shared case: ${row.name}`, () => {
      const got = parseTaskTags(row.line)
      assert.deepEqual({ content: got.content, id: got.id, due: got.due }, { content: row.content, id: row.id, due: row.due })
    })
  }
})

describe("previewBulkEntries: reordered tags", () => {
  it("shows a reversed (due) (id) line as its content, not as an id-bearing add", () => {
    const result = previewBulkEntries("## G\n- [ ] Buy milk (due: 2026-09-30) (id: 1a)\n- [ ] Buy eggs (id: 1a) (due: 2026-09-30)")
    assert.deepEqual(tasks(result).map((t) => t.content), [ "Buy milk", "Buy eggs" ])
  })
})

describe("previewBulkEntries: JSON", () => {
  it("keeps strings and objects with content, rejects a bare number", () => {
    const result = previewBulkEntries('["Buy milk", {"content": "Call plumber", "checked": true}, 42, "Water the plants"]')
    assert.equal(result.status, "ok")
    assert.equal(result.validCount, 3)
    assert.deepEqual(result.entries.map((e) => e.valid), [ true, true, false, true ])
    assert.equal(result.entries[1].checked, true)
    assert.equal(result.entries[0].checked, false)
    assert.deepEqual(result.entries[2], { kind: "task", valid: false, reason: "invalid", raw: 42 })
  })

  it("honours is_checked and done as checked aliases", () => {
    const result = previewBulkEntries('[{"content": "a", "is_checked": true}, {"content": "b", "done": true}]')
    assert.deepEqual(result.entries.map((e) => e.checked), [ true, true ])
  })

  it("rejects blank strings and objects without string content", () => {
    const result = previewBulkEntries('["   ", {"content": 5}, {}, null, ["x"]]')
    assert.equal(result.validCount, 0)
    assert.ok(result.entries.every((e) => e.valid === false && e.reason === "invalid"))
  })

  it("reports a non-array as must_be_array", () => {
    const result = previewBulkEntries("{}")
    assert.equal(result.status, "error")
    assert.equal(result.error, "must_be_array")
  })

  it("reports broken JSON and plain prose as invalid_json", () => {
    for (const raw of [ "[", "this is not json" ]) {
      const result = previewBulkEntries(raw)
      assert.equal(result.status, "error", raw)
      assert.equal(result.error, "invalid_json", raw)
    }
  })

  it("treats whitespace-only input as empty", () => {
    const result = previewBulkEntries("  \n\t ")
    assert.equal(result.status, "empty")
    assert.equal(result.error, null)
  })
})

describe("previewBulkEntries: Markdown", () => {
  it("emits headings and tasks in order", () => {
    const result = previewBulkEntries("## 買い物\n- [ ] 牛乳\n- [x] パン")
    assert.equal(result.status, "ok")
    assert.deepEqual(result.entries, [
      { kind: "heading", text: "買い物" },
      { kind: "task", valid: true, content: "牛乳", checked: false },
      { kind: "task", valid: true, content: "パン", checked: true }
    ])
    assert.equal(result.validCount, 2)
  })

  it("strips a trailing due tag and discards an id tag", () => {
    const result = previewBulkEntries("## G\n- [ ] Buy milk (due: 2026-09-30) (id: 1a)")
    assert.equal(tasks(result)[0].content, "Buy milk")
  })

  it("leaves a due-tag shape in the middle of content untouched", () => {
    const result = previewBulkEntries("## G\n- [ ] Renew (due: 2020-01-01) before it expires (id: c8)")
    assert.equal(tasks(result)[0].content, "Renew (due: 2020-01-01) before it expires")
  })

  it("rejects the exact delete marker as delete_unsupported with the raw line", () => {
    const line = "- [ ] Buy milk (id: 1a;delete!)"
    const [ task ] = tasks(previewBulkEntries(`## G\n${line}`))
    assert.deepEqual(task, { kind: "task", valid: false, reason: "delete_unsupported", raw: line })
  })

  for (const malformed of [ "(id: ABC;delete!)", "(id: c8;DELETE!)", "(id: c8 ; delete!)", "(id: ;delete!)" ]) {
    it(`keeps malformed suffix ${malformed} as inert content`, () => {
      const [ task ] = tasks(previewBulkEntries(`## G\n- [ ] Buy milk ${malformed}`))
      assert.equal(task.valid, true)
      assert.ok(task.content.includes(malformed))
    })
  }

  it("skips <details> blocks entirely", () => {
    const result = previewBulkEntries("## G\n- [ ] Keep\n<details><summary>Done</summary>\n- [x] Old (id: c9)\n</details>\n- [ ] After")
    assert.deepEqual(tasks(result).map((e) => e.content), [ "Keep", "After" ])
  })

  it("skips the Structure section until the next heading", () => {
    const result = previewBulkEntries("## Structure\n- [ ] Not a task\nNotebook A / Folder\n## Groceries\n- [ ] Buy milk")
    assert.deepEqual(result.entries, [
      { kind: "heading", text: "Groceries" },
      { kind: "task", valid: true, content: "Buy milk", checked: false }
    ])
  })

  it("parses CRLF line endings", () => {
    const result = previewBulkEntries("## G\r\n- [ ] One\r\n- [x] Two\r\n")
    assert.deepEqual(tasks(result).map((e) => [ e.content, e.checked ]), [ [ "One", false ], [ "Two", true ] ])
  })

  it("keeps HTML in content as literal text", () => {
    const [ task ] = tasks(previewBulkEntries("- [ ] <img src=x onerror=alert(1)>"))
    assert.equal(task.valid, true)
    assert.equal(task.content, "<img src=x onerror=alert(1)>")
  })

  it("rejects a task whose body is empty once tags are removed", () => {
    const line = "- [ ] (due: 2026-09-30) (id: 1a)"
    const [ task ] = tasks(previewBulkEntries(line))
    assert.equal(task.valid, false)
    assert.equal(task.reason, "invalid")
    assert.equal(task.raw, line)
  })

  it("lists prose and a checkbox-less list item as skipped, with their text", () => {
    const result = previewBulkEntries("## G\nSome prose\n* [ ] star\n1. numbered\n- [ ] Real")
    assert.deepEqual(result.entries.filter((e) => e.kind === "skipped").map((e) => e.text), [ "Some prose", "1. numbered" ])
    assert.deepEqual(tasks(result).map((e) => e.content), [ "star", "Real" ])
  })

  it("reports text with no heading or task line as invalid_json", () => {
    const result = previewBulkEntries("just some notes\nmore notes")
    assert.equal(result.status, "error")
    assert.equal(result.error, "invalid_json")
  })

  it("does not throw on a 500KB paste", () => {
    const big = "## G\n" + "- [ ] task (due: 2026-09-30) (id: 1a)\n".repeat(14000)
    assert.ok(big.length > 500_000)
    assert.equal(previewBulkEntries(big).validCount, 14000)
  })
})

// Shared with test/models/todo_paste_test.rb, lenient mode only: the preview is the bulk-add modal's grammar.
describe("previewBulkEntries: task line grammar (lenient, shared fixture)", () => {
  for (const row of sharedFixture.task_lines) {
    it(`task line: ${JSON.stringify(row.input)}`, () => {
      const found = tasks(previewBulkEntries(row.input)).map((t) => [ t.content, t.checked ])
      const expected = row.lenient.task ? [ [ row.lenient.content, row.lenient.checked ] ] : []
      assert.deepEqual(found, expected)
    })
  }

  it("keeps # to ###### lines as headings and skips a seven-hash line", () => {
    const result = previewBulkEntries("# Title\n## Note\n####### x\n- [ ] a")
    assert.deepEqual(result.entries.filter((e) => e.kind !== "task"), [
      { kind: "heading", text: "Title" },
      { kind: "heading", text: "Note" },
      { kind: "skipped", text: "####### x" }
    ])
  })
})

describe("previewBulkEntries: skipped lines", () => {
  const skipped = (result) => result.entries.filter((e) => e.kind === "skipped")

  it("lists non-task lines as skipped kind with their text", () => {
    const result = previewBulkEntries("## G\nSome prose\n- [ ] Buy milk\n- [ ]x\n<b>bold</b>")
    assert.deepEqual(skipped(result), [
      { kind: "skipped", text: "Some prose" },
      { kind: "skipped", text: "- [ ]x" },
      { kind: "skipped", text: "<b>bold</b>" }
    ])
  })

  it("shows at most five skipped lines, then one summary entry with the remaining count", () => {
    const prose = Array.from({ length: 8 }, (_, i) => `prose ${i + 1}`)
    const result = previewBulkEntries(`## G\n${prose.join("\n")}\n- [ ] Buy milk`)
    assert.deepEqual(skipped(result).map((e) => e.text), prose.slice(0, 5))
    assert.deepEqual(result.entries.filter((e) => e.kind === "more_skipped"), [ { kind: "more_skipped", count: 3 } ])
  })

  it("adds no summary entry when exactly five lines are skipped", () => {
    const prose = Array.from({ length: 5 }, (_, i) => `prose ${i + 1}`)
    const result = previewBulkEntries(`## G\n${prose.join("\n")}\n- [ ] Buy milk`)
    assert.equal(skipped(result).length, 5)
    assert.equal(result.entries.some((e) => e.kind === "more_skipped"), false)
  })

  it("does not count skipped lines as valid tasks", () => {
    const result = previewBulkEntries("## G\nprose\n- [ ] Buy milk\n-[ ] h\nmore prose")
    assert.equal(result.validCount, 1)
  })
})

describe("previewBulkEntries: the task cap", () => {
  const taskLines = (n) => Array.from({ length: n }, (_, i) => `- [ ] task ${i + 1}`).join("\n")

  it("sets tooMany with the count and max when valid tasks exceed max", () => {
    const result = previewBulkEntries(`## G\n${taskLines(3)}`, { max: 2 })
    assert.equal(result.tooMany, true)
    assert.equal(result.count, 3)
    assert.equal(result.max, 2)
  })

  it("does not set tooMany at exactly max", () => {
    assert.equal(previewBulkEntries(`## G\n${taskLines(3)}`, { max: 3 }).tooMany, false)
  })

  it("counts only valid tasks against max, not skipped lines", () => {
    const result = previewBulkEntries("## G\nprose\nprose\nprose\n- [ ] one\n- [ ] two", { max: 2 })
    assert.equal(result.tooMany, false)
  })

  it("flags 501 tasks against the 500 cap and passes 500", () => {
    const over = previewBulkEntries(`## G\n${taskLines(501)}`, { max: 500 })
    assert.equal(over.tooMany, true)
    assert.equal(over.count, 501)
    assert.equal(over.max, 500)
    assert.equal(previewBulkEntries(`## G\n${taskLines(500)}`, { max: 500 }).tooMany, false)
  })
})
