import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"
import { t } from "../lib/translations"
import { hideModal, installModalHideQueue } from "../lib/modal"
import { previewBulkEntries } from "../lib/bulk_todo_preview"

// Renders a live preview of a pasted JSON array or Markdown checklist of
// TODO tasks so a typo is visible before submitting. Convenience only —
// the server re-parses and re-validates independently.
export default class extends Controller {
  static targets = ["textarea", "preview", "error", "submit", "form"]
  static values = { max: Number }

  connect() {
    this.modal = bootstrap.Modal.getOrCreateInstance(this.element)
    // Opens via data-bs-toggle, so no show() of ours — the show-event
    // half of the queue still guards against a stale hide on reopen.
    this.modalState = installModalHideQueue(this.element, () => this.modal)
  }

  preview() {
    const result = previewBulkEntries(this.textareaTarget.value, { max: this.maxValue })

    if (result.status === "empty") return this.reset()
    if (result.status === "error") return this.showError(t(`bulk_import.${result.error}`))

    this.renderPreview(result)
  }

  renderPreview({ entries, validCount, tooMany, count, max }) {
    this.previewTarget.innerHTML = ""

    entries.forEach((entry) => {
      const li = document.createElement("li")

      if (entry.kind === "heading") {
        li.className = "list-group-item list-group-item-secondary fw-semibold"
        li.textContent = entry.text
        this.previewTarget.appendChild(li)
        return
      }

      if (entry.kind === "more_skipped") {
        li.className = "list-group-item text-muted small"
        li.textContent = t("bulk_import.more_skipped", { count: entry.count })
        this.previewTarget.appendChild(li)
        return
      }

      li.className = "list-group-item d-flex align-items-center gap-2"

      if (entry.kind === "skipped") {
        li.classList.add("list-group-item-danger")

        const label = document.createElement("span")
        label.textContent = t("bulk_import.skipped")

        const text = document.createElement("span")
        text.className = "text-break"
        text.textContent = entry.text

        li.append(warningIcon(), label, text)
      } else if (entry.valid) {
        const checkbox = document.createElement("input")
        checkbox.type = "checkbox"
        checkbox.className = "form-check-input"
        checkbox.disabled = true
        checkbox.checked = entry.checked

        const label = document.createElement("span")
        label.textContent = entry.content

        li.append(checkbox, label)
      } else {
        li.classList.add("list-group-item-danger")

        const label = document.createElement("span")
        label.textContent = entry.reason === "delete_unsupported"
          ? t("bulk_import.markdown_delete_unsupported", { raw: entry.raw })
          : t("bulk_import.skipped_invalid_task", { raw: JSON.stringify(entry.raw) })

        li.append(warningIcon(), label)
      }

      this.previewTarget.appendChild(li)
    })

    if (tooMany) {
      this.showMessage(t("bulk_import.too_many", { count, max }))
      this.submitTarget.disabled = true
    } else {
      this.errorTarget.classList.add("d-none")
      this.submitTarget.disabled = validCount === 0
    }
  }

  showError(message) {
    this.previewTarget.innerHTML = ""
    this.submitTarget.disabled = true
    this.showMessage(message)
  }

  showMessage(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("d-none")
  }

  reset() {
    this.previewTarget.innerHTML = ""
    this.submitTarget.disabled = true
    this.errorTarget.classList.add("d-none")
  }

  // Only close and clear the modal once the import actually went through —
  // a failed request (e.g. a dropped connection) should leave the pasted
  // JSON in place so nothing is lost.
  submitStart() {
    this.errorTarget.classList.add("d-none")
  }

  submitEnd(event) {
    if (event.detail.success) {
      this.formTarget.reset()
      this.reset()
      hideModal(this.modalState, this.modal)
      return
    }

    this.showMessage(t("forms.add_failed"))
  }
}

function warningIcon() {
  const icon = document.createElement("i")
  icon.className = "bi bi-exclamation-triangle-fill"
  return icon
}
