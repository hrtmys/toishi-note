import { Controller } from "@hotwired/stimulus"
import { renderMarkdownIntoElement } from "../lib/markdown_renderer"

export default class extends Controller {
  static targets = [
    "textarea", "previewArea", "editorContainer",
    "editBtn", "splitBtn", "previewBtn"
  ]

  connect() {
    this.mode = localStorage.getItem("editorMode") || "split"
    // "diff"/"compare" were previous names for a 4th tab that no longer
    // exists (now the Compare modal) — fall back to split for old values.
    if (this.mode === "diff" || this.mode === "compare") this.mode = "split"
    this.applyMode()
    this.renderPreviewNow()
  }

  showEdit() { this.mode = "edit"; this.applyMode(); }
  showSplit() { this.mode = "split"; this.applyMode(); this.renderPreviewNow(); }
  showPreview() { this.mode = "preview"; this.applyMode(); this.renderPreviewNow(); }

  applyMode() {
    // Persist the chosen mode across reloads.
    localStorage.setItem("editorMode", this.mode);

    [this.editBtnTarget, this.splitBtnTarget, this.previewBtnTarget].forEach(btn => btn.classList.remove("active"))
    this.setPane(this.editorContainerTarget, "hidden")
    this.setPane(this.previewAreaTarget, "hidden")

    if (this.mode === "edit") {
      this.editBtnTarget.classList.add("active")
      this.setPane(this.editorContainerTarget, "full")
    } else if (this.mode === "split") {
      this.splitBtnTarget.classList.add("active")
      this.setPane(this.editorContainerTarget, "half")
      this.setPane(this.previewAreaTarget, "half")
    } else if (this.mode === "preview") {
      this.previewBtnTarget.classList.add("active")
      this.setPane(this.previewAreaTarget, "full")
    }
  }

  // A pane is either hidden, half-width (split view), or full-width.
  setPane(element, state) {
    element.classList.remove("d-none", "w-50", "w-100")
    if (state === "hidden") element.classList.add("d-none")
    if (state === "half") element.classList.add("w-50")
    if (state === "full") element.classList.add("w-100")
  }

  // Every keystroke re-renders the whole preview including Mermaid/KaTeX,
  // so coalesce bursts into one trailing render. Mode switches bypass the
  // timer via renderPreviewNow so they stay instant. Autosave has its own
  // separate (longer) debounce; this one only governs preview painting.
  updatePreview() {
    if (this.mode === "edit") return

    clearTimeout(this.previewTimer)
    this.previewTimer = setTimeout(() => this.renderPreviewNow(), 200)
  }

  renderPreviewNow() {
    if (this.mode === "edit") return

    clearTimeout(this.previewTimer)
    renderMarkdownIntoElement(this.previewAreaTarget, this.textareaTarget.value)
  }

  disconnect() {
    clearTimeout(this.previewTimer)
  }
}
