// Unit tests for lib/markdown_source.js: the shared source normalization
// that the preview renderer, the scroll anchor and the Word copy all use.
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { marked } from "../../app/javascript/lib/marked_config.js"
import * as source from "../../app/javascript/lib/markdown_source.js"

describe("normalizeListGaps", () => {
  it("turns a full-width gap after a bullet into an ASCII space", () => {
    assert.equal(source.normalizeListGaps("-　a"), "- a")
  })

  it("leaves an ordered item with an ASCII gap unchanged", () => {
    assert.equal(source.normalizeListGaps("1. a"), "1. a")
  })

  it("leaves an ASCII bullet unchanged", () => {
    assert.equal(source.normalizeListGaps("- a"), "- a")
  })

  it("turns a full-width gap after a task box into an ASCII space", () => {
    assert.equal(source.normalizeListGaps("- [x]　done"), "- [x] done")
  })

  it("leaves a bare marker with a full-width gap and no content unchanged", () => {
    assert.equal(source.normalizeListGaps("para\n-　"), "para\n-　")
  })

  it("leaves list-like lines inside a backtick fence unchanged", () => {
    assert.equal(source.normalizeListGaps("```\n-　a\n```"), "```\n-　a\n```")
  })

  it("closes a tilde fence only with a closer of at least the same length", () => {
    assert.equal(
      source.normalizeListGaps("~~~~\n1.　x\n~~~\n~~~~\n-　b"),
      "~~~~\n1.　x\n~~~\n~~~~\n- b"
    )
  })

  it("leaves a line with a leading full-width space unchanged", () => {
    assert.equal(source.normalizeListGaps("　- a"), "　- a")
  })

  it("leaves a Japanese middle-dot bullet unchanged", () => {
    assert.equal(source.normalizeListGaps("・a"), "・a")
  })

  it("normalizes both gaps around a task box", () => {
    assert.equal(source.normalizeListGaps("-　[ ]　x"), "- [ ] x")
  })

  it("turns a full-width gap after a bullet inside a quote into an ASCII space", () => {
    assert.equal(source.normalizeListGaps("> -\u3000a"), "> - a")
  })

  it("turns a full-width gap after a quote marker into an ASCII space", () => {
    assert.equal(source.normalizeListGaps(">\u3000- a"), "> - a")
  })

  it("keeps an unclosed fence open to the end of the document", () => {
    assert.equal(source.normalizeListGaps("```\n-　a"), "```\n-　a")
  })

  it("does not treat a closer with an info string as closing the fence", () => {
    assert.equal(source.normalizeListGaps("```\n```js\n-　a"), "```\n```js\n-　a")
  })

  it("does not treat a backtick fence whose info string has a backtick as a fence", () => {
    assert.equal(source.normalizeListGaps("``` a`b\n-　a"), "``` a`b\n- a")
  })

  it("does not treat a fence indented four spaces as a fence", () => {
    assert.equal(source.normalizeListGaps("    ```\n-　a"), "    ```\n- a")
  })

  it("keeps the length of the input for every input", () => {
    const inputs = [
      "-　a",
      "- [x]　done",
      "-\u00A0\u00A0a",
      "1.　x\n-　b",
      "```\n-　a\n```",
      "~~~~\n1.　x\n~~~\n~~~~\n-　b",
      "-　",
      "　- a",
      "-　[ ]　x",
    ]
    for (const input of inputs) {
      assert.equal(source.normalizeListGaps(input).length, input.length, JSON.stringify(input))
    }
  })
})

describe("fenceStep", () => {
  // Folds fenceStep over the lines, starting from null (no open fence).
  const fenceFlags = (lines) => {
    let fence = null
    return lines.map((line) => {
      const step = source.fenceStep(fence, line)
      fence = step.fence
      return step.inFence
    })
  }

  it("marks the opener, body and closer as inside and the line after the closer as outside", () => {
    assert.deepEqual(fenceFlags(["```", "x", "```", "after"]), [true, true, true, false])
  })

  it("keeps an unclosed fence open to the end", () => {
    assert.deepEqual(fenceFlags(["```js", "x", "y"]), [true, true, true])
  })

  it("does not close a four-tilde fence with a three-tilde line", () => {
    assert.deepEqual(fenceFlags(["~~~~", "~~~", "x", "~~~~", "after"]), [true, true, true, true, false])
  })

  it("does not treat a fence indented four spaces as an opener", () => {
    assert.deepEqual(fenceFlags(["    ```", "x"]), [false, false])
  })

  it("does not treat a backtick opener whose info string has a backtick as an opener", () => {
    assert.deepEqual(fenceFlags(["``` a`b", "x"]), [false, false])
  })
})

describe("insideFence", () => {
  it("is true for a line in the body of a fence", () => {
    assert.equal(source.insideFence("```\n- a\n```", 4), true)
  })

  it("is false for a line after the closer", () => {
    assert.equal(source.insideFence("```\nx\n```\n- a", 10), false)
  })

  it("is true for a line inside an unclosed fence", () => {
    assert.equal(source.insideFence("```js\n1. a", 6), true)
  })
})

describe("trimMarkdown", () => {
  it("trims leading and trailing newlines", () => {
    assert.equal(source.trimMarkdown("\n\n# A\n\n"), "# A")
  })

  it("does not trim a trailing full-width space", () => {
    assert.equal(source.trimMarkdown("para\n-　"), "para\n-　")
  })
})

describe("rendering normalized source", () => {
  const render = (markdown) => marked.parse(source.normalizeListGaps(source.trimMarkdown(markdown)))

  it("does not render a full-width-gapped dash after a paragraph as a heading", () => {
    assert.doesNotMatch(render("para\n-　"), /<h2>/)
  })

  it("renders a full-width-gapped bullet as a list item", () => {
    assert.match(render("-　a"), /<ul>\s*<li>/)
  })
})

describe("normalizeListGaps with a no-break space", () => {
  it("rewrites a no-break space after a bullet, a number, and a quoted bullet", () => {
    assert.equal(source.normalizeListGaps("-\u00A0a"), "- a")
    assert.equal(source.normalizeListGaps("1.\u00A0a"), "1. a")
    assert.equal(source.normalizeListGaps("> -\u00A0a"), "> - a")
  })
})
