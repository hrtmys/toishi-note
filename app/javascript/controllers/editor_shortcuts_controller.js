import { Controller } from "@hotwired/stimulus"
import { currentLine } from "../lib/list_marker"

// The roadmap v0.2 editor batch: Ctrl/Cmd+B bold, Ctrl/Cmd+I italic,
// Ctrl/Cmd+K link, Ctrl/Cmd+Shift+K delete line, and pasting a URL over
// a selection turning it into [selection](url). Plain-textarea
// behaviors, no editor framework. Two constraints from roadmap section
// 5 #4 apply to every method here: all edits go through
// execCommand("insertText") so Ctrl+Z keeps working, and every handler
// bails while isComposing so Japanese IME input never breaks.
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
    // A URL pasted over a selection becomes a link, instead of replacing
    // the selection with the bare URL. Runs after word-paste and
    // image-upload in the textarea's action list: rich HTML pastes are
    // already consumed (converted or dispatched) by then, and anything
    // carrying an image item belongs to image-upload.
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
