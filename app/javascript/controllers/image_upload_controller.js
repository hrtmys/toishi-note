import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

// Handles pasting/dragging an image into the editor's textarea. A grey
// placeholder swaps for the real Markdown once upload responds.
// Registered after word-paste's handler, which gets first look.
export default class extends Controller {
  static values = { url: String }

  paste(event) {
    const item = Array.from(event.clipboardData?.items || []).find((candidate) => candidate.type.startsWith("image/"))
    if (!item) return

    event.preventDefault()
    this.upload(item.getAsFile())
  }

  drop(event) {
    const file = Array.from(event.dataTransfer?.files || []).find((candidate) => candidate.type.startsWith("image/"))
    if (!file) return

    event.preventDefault()
    this.upload(file)
  }

  // Without this, the browser's default dragover handling blocks drop
  // from firing at all.
  dragover(event) {
    event.preventDefault()
  }

  upload(file) {
    const textarea = this.element
    const placeholder = `![${t("image_upload.uploading", { filename: file.name })}]()`

    this.insertAtCursor(textarea, placeholder)

    const formData = new FormData()
    formData.append("image", file)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
      },
      body: formData,
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Upload failed: ${response.status}`)
        return response.json()
      })
      .then(({ markdown }) => this.replaceText(textarea, placeholder, markdown))
      .catch((error) => {
        console.error("Image upload failed", error)
        this.replaceText(textarea, placeholder, `![${t("image_upload.failed", { filename: file.name })}]()`)
      })
  }

  insertAtCursor(textarea, text) {
    const start = textarea.selectionStart ?? textarea.value.length
    const end = textarea.selectionEnd ?? textarea.value.length

    textarea.setRangeText(text, start, end, "end")
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }

  replaceText(textarea, from, to) {
    textarea.value = textarea.value.replace(from, to)
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
