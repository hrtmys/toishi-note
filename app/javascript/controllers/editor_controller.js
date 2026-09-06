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
    this.updatePreview()
    this.setupPreviewScrollStability()
  }

  disconnect() {
    this.teardownPreviewScrollStability()
  }

  showEdit() { this.mode = "edit"; this.applyMode(); }
  showSplit() { this.mode = "split"; this.applyMode(); this.updatePreview(); }
  showPreview() { this.mode = "preview"; this.applyMode(); this.updatePreview(); }

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

  updatePreview() {
    if (this.mode === "edit") return;

    // Every keystroke replaces preview innerHTML wholesale, destroying the
    // node the browser's scroll anchoring would hold on to — scrollTop stays
    // fixed while scrollHeight changes, so the view drifts, and late
    // Mermaid/KaTeX inserts grow the height again after the fact. Pin the
    // relative position here, restore it right after the sync render, and
    // let the MutationObserver below re-apply it while async inserts land.
    const preview = this.previewAreaTarget
    const max = preview.scrollHeight - preview.clientHeight
    this._pinnedRatio = max <= 0 ? 0 : preview.scrollTop / max
    this._pinnedToBottom = max > 0 && (max - preview.scrollTop) < 2
    this._restoreUntil = Date.now() + 800

    renderMarkdownIntoElement(preview, this.textareaTarget.value)

    this.restorePinnedPreviewScroll()
  }

  // One-way editor -> preview proportional follow. Preview -> editor is
  // deliberately absent, and a manual preview scroll clears the pinned
  // ratio (see _onPreviewScroll), so the two never fight each other.
  setupPreviewScrollStability() {
    this._pinnedRatio = null
    this._pinnedToBottom = false
    this._restoreUntil = 0
    this._applyingScroll = false
    this._lastAppliedScrollTop = null

    this._onTextareaScroll = () => this.syncPreviewToEditor()
    this._onPreviewScroll = () => {
      if (this._applyingScroll) return
      // A programmatic restore lands exactly on the value it applied —
      // anything else is the user taking over, so stop re-pinning.
      if (this._lastAppliedScrollTop !== null &&
          Math.abs(this.previewAreaTarget.scrollTop - this._lastAppliedScrollTop) < 1) return
      this._pinnedRatio = null
    }
    this.textareaTarget.addEventListener("scroll", this._onTextareaScroll)
    this.previewAreaTarget.addEventListener("scroll", this._onPreviewScroll)

    this._previewObserver = new MutationObserver(() => this.restorePinnedPreviewScroll())
    this._previewObserver.observe(this.previewAreaTarget, { childList: true, subtree: true })
  }

  teardownPreviewScrollStability() {
    if (this._onTextareaScroll) {
      this.textareaTarget.removeEventListener("scroll", this._onTextareaScroll)
      this._onTextareaScroll = null
    }
    if (this._onPreviewScroll) {
      this.previewAreaTarget.removeEventListener("scroll", this._onPreviewScroll)
      this._onPreviewScroll = null
    }
    if (this._previewObserver) {
      this._previewObserver.disconnect()
      this._previewObserver = null
    }
    this._pinnedRatio = null
  }

  syncPreviewToEditor() {
    if (this.mode === "edit") return
    const editor = this.textareaTarget
    const editorMax = editor.scrollHeight - editor.clientHeight
    const ratio = editorMax <= 0 ? 0 : editor.scrollTop / editorMax
    this._pinnedRatio = ratio
    this._pinnedToBottom = ratio > 0.98
    this._restoreUntil = Date.now() + 800
    this.restorePinnedPreviewScroll()
  }

  restorePinnedPreviewScroll() {
    if (this._pinnedRatio === null) return
    if (Date.now() > this._restoreUntil) {
      this._pinnedRatio = null
      return
    }
    const preview = this.previewAreaTarget
    const max = preview.scrollHeight - preview.clientHeight
    this._applyingScroll = true
    try {
      preview.scrollTop = Math.round(this._pinnedToBottom ? Math.max(max, 0) : this._pinnedRatio * Math.max(max, 0))
      this._lastAppliedScrollTop = preview.scrollTop
    } finally {
      // The scroll event from a programmatic scrollTop is dispatched
      // asynchronously — clearing the guard on a timer (not synchronously)
      // keeps the resulting event from looking like a manual scroll.
      const token = (this._scrollToken = (this._scrollToken || 0) + 1)
      setTimeout(() => {
        if (this._scrollToken === token) this._applyingScroll = false
      }, 50)
    }
  }
}
