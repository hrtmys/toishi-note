import { Controller } from "@hotwired/stimulus"
import { renderMarkdownIntoElement } from "../lib/markdown_renderer"

export default class extends Controller {
  connect() {
    renderMarkdownIntoElement(this.element, this.element.textContent)
  }
}