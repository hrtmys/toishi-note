import { Controller } from "@hotwired/stimulus"
import { currentLine } from "../lib/list_marker"

// v0.2 editor batch (bold/italic/link/delete-line/URL-paste).
// Plain-textarea behaviors; every edit uses execCommand("insertText")
// so Ctrl+Z keeps working, and handlers bail while isComposing.
export default class extends Controller {
  keydown(event) {
    // Mid-composition keydowns (including the Enter confirming a
    // conversion) must never trigger a shortcut.
    if (event.isComposing) return
    if ((!event.ctrlKey && !event.metaKey) || event.altKey) return

    const key = event.key.toLowerCase()
    if (key === "b" && !event.shiftKey) {
      event.preventDefault()
      this.wrapSelection("**")
    } else if (key === "i" && !event.shiftKey) {
      event.preventDefault()
      this.wrapSelection("*")
    } else if (key === "k" && !event.shiftKey) {
      event.preventDefault()
      this.insertLink()
    } else if (key === "k" && event.shiftKey) {
      event.preventDefault()
      this.deleteLine()
    }
  }

  paste(event) {
    // URL over a selection becomes [selection](url). Runs after
    // word-paste/image-upload, so rich HTML and image items are theirs.
    if (event.isComposing) return

    const textarea = this.element
    const { selectionStart, selectionEnd } = textarea
    if (selectionStart === selectionEnd) return
    if (hasImageItem(event)) return

    const text = event.clipboardData?.getData("text/plain")?.trim()
    if (!text || !/^https?:\/\/\S+$/i.test(text)) return

    const selected = textarea.value.slice(selectionStart, selectionEnd)
    event.preventDefault()
    event.stopImmediatePropagation()
    document.execCommand("insertText", false, `[${selected}](${text})`)
  }

  wrapSelection(fence) {
    const textarea = this.element
    const { selectionStart, selectionEnd, value } = textarea

    if (selectionStart === selectionEnd) {
      // No selection: drop a fenced pair and park the caret between the
      // fences so the user types the emphasized text directly.
      document.execCommand("insertText", false, fence + fence)
      const caret = selectionStart + fence.length
      textarea.setSelectionRange(caret, caret)
    } else {
      const selected = value.slice(selectionStart, selectionEnd)
      textarea.setSelectionRange(selectionStart, selectionEnd)
      document.execCommand("insertText", false, `${fence}${selected}${fence}`)
      const caret = selectionEnd + fence.length * 2
      textarea.setSelectionRange(caret, caret)
    }
  }

  insertLink() {
    const textarea = this.element
    const { selectionStart, selectionEnd, value } = textarea

    if (selectionStart === selectionEnd) {
      // Nothing selected: insert a link skeleton and select the text
      // placeholder, the part the user most likely edits first.
      document.execCommand("insertText", false, "[text](url)")
      textarea.setSelectionRange(selectionStart + 1, selectionStart + 5)
    } else {
      const selected = value.slice(selectionStart, selectionEnd)
      textarea.setSelectionRange(selectionStart, selectionEnd)
      document.execCommand("insertText", false, `[${selected}](url)`)
      const urlStart = selectionStart + selected.length + 3
      textarea.setSelectionRange(urlStart, urlStart + 3)
    }
  }

  deleteLine() {
    const textarea = this.element
    const { selectionStart, selectionEnd, value } = textarea

    // A range selection deletes every line it touches; a bare caret
    // deletes its own line.
    const { lineStart } = currentLine(value, selectionStart)
    const { lineEnd } = currentLine(value, selectionEnd)

    // Swallow one adjacent newline so no blank line is left behind —
    // the trailing one, or the leading one when on the last line.
    let delStart = lineStart
    let delEnd = lineEnd
    if (value[delEnd] === "\n") {
      delEnd += 1
    } else if (delStart > 0) {
      delStart -= 1
    }

    textarea.setSelectionRange(delStart, delEnd)
    document.execCommand("insertText", false, "")
  }
}

// Mirrors word_paste_controller.js's trigger: a clipboard item whose type
// starts with "image/" means a picture came along — image-upload owns it.
function hasImageItem(event) {
  return Array.from(event.clipboardData?.items || []).some((item) => item.type.startsWith("image/"))
}
