import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"
import { t } from "../lib/translations"

// Renders a live preview of a pasted JSON array of TODO tasks so a typo
// is visible before submitting. Convenience only — the server re-parses
// and re-validates independently.
export default class extends Controller {
  static targets = ["textarea", "preview", "error", "submit", "form"]

  connect() {
    this.modal = bootstrap.Modal.getOrCreateInstance(this.element)
  }

  preview() {
    const raw = this.textareaTarget.value.trim()

    if (raw === "") {
      this.reset()
      return
    }

    let parsed
    try {
      parsed = JSON.parse(raw)
    } catch (error) {
      this.showError(t("bulk_import.invalid_json"))
      return
    }

    if (!Array.isArray(parsed)) {
      this.showError(t("bulk_import.must_be_array"))
      return
    }

    this.renderPreview(parsed.map((entry) => this.classify(entry)))
  }

  classify(entry) {
    if (typeof entry === "string") {
      const content = entry.trim()
      return content ? { valid: true, content, checked: false } : { valid: false, raw: entry }
    }

    if (entry && typeof entry === "object" && !Array.isArray(entry)) {
      const content = typeof entry.content === "string" ? entry.content.trim() : ""
      if (content) {
        return { valid: true, content, checked: !!(entry.checked ?? entry.is_checked ?? entry.done) }
      }
    }

    return { valid: false, raw: entry }
  }

  renderPreview(entries) {
    this.errorTarget.classList.add("d-none")
    this.previewTarget.innerHTML = ""

    let validCount = 0

    entries.forEach((entry) => {
      const li = document.createElement("li")
      li.className = "list-group-item d-flex align-items-center gap-2"

      if (entry.valid) {
        validCount += 1
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

        const icon = document.createElement("i")
        icon.className = "bi bi-exclamation-triangle-fill"

        const label = document.createElement("span")
        label.textContent = t("bulk_import.skipped_invalid_task", { raw: JSON.stringify(entry.raw) })

        li.append(icon, label)
      }

      this.previewTarget.appendChild(li)
    })

    this.submitTarget.disabled = validCount === 0
  }

  showError(message) {
    this.previewTarget.innerHTML = ""
    this.submitTarget.disabled = true
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
  submitEnd(event) {
    if (event.detail.success) {
      this.formTarget.reset()
      this.reset()
      this.modal.hide()
    }
  }
}
