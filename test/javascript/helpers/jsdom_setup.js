// jsdom globals for the JS unit tests. Must be the FIRST static
// import in files touching turndown/DOMPurify (they read globals
// once, at module load time).
import { JSDOM } from "jsdom"

const dom = new JSDOM("", { url: "http://localhost/" })

globalThis.window = dom.window
globalThis.document = dom.window.document
globalThis.DOMParser = dom.window.DOMParser
globalThis.Node = dom.window.Node
globalThis.Element = dom.window.Element
globalThis.HTMLElement = dom.window.HTMLElement
