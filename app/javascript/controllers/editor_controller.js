import { Controller } from "@hotwired/stimulus"
import { renderMarkdownIntoElement } from "../lib/markdown_renderer"
import { previewAnchor, revealScrollTop } from "../lib/scroll_follow"

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
    this.setupPreviewScrollStability()
    this.renderPreviewNow()
  }

  disconnect() {
    clearTimeout(this.previewTimer)
    this.teardownPreviewScrollStability()
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

    // Stamp when the textarea's value last changed via user input. The
    // scroll handler below uses this to tell a real deliberate scroll
    // apart from the browser's own caret-follow autoscroll.
    this._lastInputAt = Date.now()

    // Captured now: by the debounced render the caret may have moved on.
    this._followCaret = true
    this._followCaretPos = this.textareaTarget.selectionEnd

    clearTimeout(this.previewTimer)
    this.previewTimer = setTimeout(() => this.renderPreviewNow(), 200)
  }

  renderPreviewNow() {
    if (this.mode === "edit") return

    clearTimeout(this.previewTimer)

    // Every keystroke replaces preview innerHTML wholesale, destroying the
    // node the browser's scroll anchoring would hold on to — scrollTop stays
    // fixed while scrollHeight changes, so the view drifts, and late
    // Mermaid/KaTeX inserts grow the height again after the fact. Pin the
    // relative position here, restore it right after the sync render, and
    // let the MutationObserver below re-apply it while async inserts land.
    const preview = this.previewAreaTarget
    const follow = this._followCaret
    this._followCaret = false
    this._pinMode = follow ? "follow" : "ratio"
    if (follow) this._followAnchor = previewAnchor(this.textareaTarget.value, this._followCaretPos)
    const max = preview.scrollHeight - preview.clientHeight
    this._pinnedRatio = max <= 0 ? 0 : preview.scrollTop / max
    this._pinnedToBottom = max > 0 && (max - preview.scrollTop) < 2
    this._restoreUntil = Date.now() + 800

    renderMarkdownIntoElement(preview, this.textareaTarget.value)

    this.restorePinnedPreviewScroll()
  }

  // One-way editor -> preview proportional follow. Preview -> editor is
  // deliberately absent, and a manual preview scroll clears the pin
  // (see _onPreviewScroll), so the two never fight each other.
  setupPreviewScrollStability() {
    this._pinMode = null
    this._pinnedRatio = null
    this._pinnedToBottom = false
    this._followCaret = false
    this._followCaretPos = 0
    this._followAnchor = null
    this._restoreUntil = 0
    this._applyingScroll = false
    this._lastAppliedScrollTop = null
    this._lastInputAt = 0

    this._onTextareaScroll = () => {
      // A `scroll` event on the textarea fires identically whether the user
      // deliberately scrolled it (wheel/trackpad/scrollbar-drag/PageDown) or
      // the browser auto-scrolled it to keep the caret visible while typing
      // (completely normal behavior — real typing triggers it too, not just
      // Capybara's fill_in). Caret-follow autoscroll happens synchronously
      // as a direct consequence of the value changing, so it always lands
      // within a few ms of the `input` event that caused it; a genuine
      // user-driven scroll has no such correlation. Use that timing gap to
      // ignore caret-follow scrolls without disabling deliberate-scroll
      // follow (including a programmatic `scrollTop` assignment, which
      // isn't preceded by an `input` event at all).
      if (Date.now() - this._lastInputAt < 100) return
      this.syncPreviewToEditor()
    }
    this._onPreviewScroll = () => {
      // A programmatic restore lands exactly on the value it applied, or on the
      // clamped bottom if the content shrank meanwhile; anything else is the user.
      const preview = this.previewAreaTarget
      if (this._lastAppliedScrollTop !== null &&
          Math.abs(preview.scrollTop - this._lastAppliedScrollTop) < 1) return
      if (this._applyingScroll && preview.scrollTop >= preview.scrollHeight - preview.clientHeight - 1) return
      this._pinMode = null
      this._pinnedRatio = null
      this._followCaret = false
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
    this._pinMode = null
    this._pinnedRatio = null
  }

  syncPreviewToEditor() {
    if (this.mode === "edit") return
    const editor = this.textareaTarget
    const editorMax = editor.scrollHeight - editor.clientHeight
    const ratio = editorMax <= 0 ? 0 : editor.scrollTop / editorMax
    this._pinMode = "ratio"
    this._followCaret = false
    this._pinnedRatio = ratio
    this._pinnedToBottom = ratio > 0.98
    this._restoreUntil = Date.now() + 800
    this.restorePinnedPreviewScroll()
  }

  restorePinnedPreviewScroll() {
    if (this._pinMode === null) return
    if (Date.now() > this._restoreUntil) {
      this._pinMode = null
      this._pinnedRatio = null
      return
    }
    const preview = this.previewAreaTarget
    const max = preview.scrollHeight - preview.clientHeight
    const top = this._pinMode === "follow"
      ? this.followTop()
      : Math.round(this._pinnedToBottom ? Math.max(max, 0) : this._pinnedRatio * Math.max(max, 0))
    if (top === null) return
    this._applyingScroll = true
    try {
      preview.scrollTop = top
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

  // Block indices only map to children while the renderer keeps one element per token.
  followTop() {
    const preview = this.previewAreaTarget
    const anchor = this._followAnchor
    if (anchor === null) return null

    let top = 0
    let height = preview.scrollHeight
    if (anchor.block !== null && preview.children.length === anchor.count) {
      const rect = preview.children[anchor.block].getBoundingClientRect()
      top = rect.top - preview.getBoundingClientRect().top + preview.scrollTop
      height = rect.height
    }

    return revealScrollTop({
      top: top + anchor.start * height,
      bottom: top + anchor.end * height,
      scrollTop: preview.scrollTop,
      viewHeight: preview.clientHeight,
      maxScrollTop: preview.scrollHeight - preview.clientHeight,
      margin: 40
    })
  }
}
