// Expected structures were pinned against GitHub's own gfm renderer.
import "./helpers/jsdom_setup.js"
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { renderMarkdownIntoElement, setMermaidModuleLoaderForTest } from "../../app/javascript/lib/markdown_renderer.js"

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

  it("draws an indented table even when the same header line recurs lazily later in the item", () => {
    const element = render("- a\n  | x | y |\n  |---|---|\n  | 1 | 2 |\n\n  para\n| x | y |\n|---|---|")
    assert.equal(element.querySelectorAll("li table").length, 1)
    assert.match(element.querySelector("li p:last-child").textContent, /^para\n\| x \| y \|\n\|---\|---\|$/)
  })

  it("draws a table when only the header line is lazy", () => {
    assert.ok(render("- a\n| x | y |\n  |---|---|").querySelector("li table"))
  })

  it("keeps text when only the delimiter row is lazy", () => {
    const element = render("- a\n  | x | y |\n|---|---|\n| 1 | 2 |")
    assert.equal(element.querySelector("table"), null)
    assert.match(element.querySelector("li").textContent, /^a\n\| x \| y \|\n\|---\|---\|\n\| 1 \| 2 \|$/)
  })
})

// The real Mermaid never finishes under jsdom (it measures text via
// layout APIs), so a counting fake drives the public entry point. Each
// test uses its own source: the SVG cache is module-level.
describe("renderMarkdownIntoElement: Mermaid diagrams", () => {
  function fakeMermaid() {
    const renderedSources = []
    return {
      renderedSources,
      initialize() {},
      async render(_id, source) {
        renderedSources.push(source)
        return { svg: `<svg data-render="${renderedSources.length}"></svg>` }
      }
    }
  }

  function connectedElement() {
    const element = document.createElement("div")
    document.body.appendChild(element)
    return element
  }

  // The render entry point does not await its Mermaid pass; poll a few
  // macrotask turns until the diagram has been swapped in.
  async function waitForDiagram(element) {
    for (let attempt = 0; attempt < 50 && !element.querySelector("div.mermaid svg"); attempt++) {
      await new Promise((resolve) => setTimeout(resolve, 0))
    }
    assert.ok(element.querySelector("div.mermaid svg"), "expected the diagram to be rendered")
  }

  it("renders an unchanged diagram only once across re-renders", async () => {
    const mermaid = fakeMermaid()
    setMermaidModuleLoaderForTest(async () => ({ default: mermaid }))
    const element = connectedElement()
    const markdown = "before\n\n```mermaid\ngraph TD\n  A --> B\n```"

    renderMarkdownIntoElement(element, markdown)
    await waitForDiagram(element)
    assert.equal(mermaid.renderedSources.length, 1)
    const firstSvg = element.querySelector("div.mermaid").innerHTML

    // Typing elsewhere in the note rebuilds the preview from source;
    // the cached SVG is swapped back in the same synchronous pass, so
    // no frame shows the raw code block and Mermaid is not called again.
    renderMarkdownIntoElement(element, `${markdown}\n\nafter`)
    assert.equal(element.querySelector("div.mermaid").innerHTML, firstSvg)
    await waitForDiagram(element)
    assert.equal(mermaid.renderedSources.length, 1)
  })

  it("re-renders a diagram whose source changed", async () => {
    const mermaid = fakeMermaid()
    setMermaidModuleLoaderForTest(async () => ({ default: mermaid }))
    const element = connectedElement()

    renderMarkdownIntoElement(element, "```mermaid\ngraph TD\n  C --> D\n```")
    await waitForDiagram(element)
    assert.equal(mermaid.renderedSources.length, 1)
    const firstSvg = element.querySelector("div.mermaid").innerHTML

    renderMarkdownIntoElement(element, "```mermaid\ngraph TD\n  C --> E\n```")
    await waitForDiagram(element)
    assert.equal(mermaid.renderedSources.length, 2)
    assert.match(mermaid.renderedSources[1], /C --> E/)
    assert.notEqual(element.querySelector("div.mermaid").innerHTML, firstSvg)
  })
})
