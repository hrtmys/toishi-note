import { Controller } from "@hotwired/stimulus"
import { deleteLineEdit, linkEdit, performEdit, shortcutCommand, urlPasteEdit, wrapEdit } from "../lib/markdown_edits"

// Every edit goes through execCommand("insertText") so Ctrl+Z keeps working.
export default class extends Controller {
  keydown(event) {
    const command = shortcutCommand(event)
    if (!command) return

    event.preventDefault()
    const { selectionStart, selectionEnd, value } = this.element
    const edit = {
      bold: () => wrapEdit(value, selectionStart, selectionEnd, "**"),
      italic: () => wrapEdit(value, selectionStart, selectionEnd, "*"),
      link: () => linkEdit(value, selectionStart, selectionEnd),
      deleteLine: () => deleteLineEdit(value, selectionStart, selectionEnd)
    }[command]()
    performEdit(this.element, edit)
  }

  paste(event) {
    // URL over a selection becomes [selection](url). Runs after
    // word-paste/image-upload, so rich HTML and image items are theirs.
    if (event.isComposing) return

    const { selectionStart, selectionEnd, value } = this.element
    const edit = urlPasteEdit(value, selectionStart, selectionEnd, event.clipboardData?.getData("text/plain"), hasImageItem(event))
    if (!edit) return

    event.preventDefault()
    event.stopImmediatePropagation()
    performEdit(this.element, edit)
  }
}

// Mirrors word_paste_controller.js's trigger: a clipboard item whose type
// starts with "image/" means a picture came along — image-upload owns it.
function hasImageItem(event) {
  return Array.from(event.clipboardData?.items || []).some((item) => item.type.startsWith("image/"))
}
