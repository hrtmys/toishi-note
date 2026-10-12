// Expected structures were pinned against GitHub's own gfm renderer.
import "./helpers/jsdom_setup.js"
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { renderMarkdownIntoElement } from "../../app/javascript/lib/markdown_renderer.js"

const TABLE = "| x | y |\n|---|---|\n| 1 | 2 |"

function render(markdown) {
  const element = document.createElement("div")
  renderMarkdownIntoElement(element, markdown)
  return element
}

describe("renderMarkdownIntoElement: a table next to a list item", () => {
  it("keeps unindented pipe lines right after an item as lazy item text", () => {
    const element = render(`- a\n${TABLE}`)
    assert.equal(element.querySelector("table"), null)
    assert.match(element.querySelector("li").textContent, /^a\n\| x \| y \|\n\|---\|---\|\n\| 1 \| 2 \|$/)
  })

  it("renders a table after a blank line outside the list", () => {
    const element = render(`- a\n\n${TABLE}`)
    assert.equal(element.querySelector("li table"), null)
    assert.equal(element.querySelector(":scope > table").rows.length, 2)
  })

  it("renders a table indented under an item inside the item", () => {
    assert.ok(render("- a\n\n  " + TABLE.replaceAll("\n", "\n  ")).querySelector("li table"))
    assert.ok(render("- a\n  " + TABLE.replaceAll("\n", "\n  ")).querySelector("li table"))
  })

  it("lets a table interrupt a paragraph outside a list", () => {
    const element = render(`para\n${TABLE}`)
    assert.equal(element.querySelector("p").textContent, "para")
    assert.ok(element.querySelector(":scope > table"))
  })
})
