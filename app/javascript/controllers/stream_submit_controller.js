import { Controller } from "@hotwired/stimulus"
import { createSerialQueue } from "../lib/serial_queue"
import { submitOutcome } from "../lib/submit_outcome"
import { t } from "../lib/translations"

// Page-wide, so requests stay ordered across Turbo visits.
const queue = createSerialQueue()

export default class extends Controller {
  static values = { reportFailure: { type: Boolean, default: true } }

  submit(event) {
    event.preventDefault()

    const form = this.element
    const submitter = event.submitter
    const message = submitter?.dataset.turboConfirm ?? form.dataset.turboConfirm
    if (message && !window.confirm(message)) return

    // URL-encoded like Turbo: multipart would store textarea newlines as CRLF.
    const body = new URLSearchParams(submitter ? new FormData(form, submitter) : new FormData(form))
    if (submitter) submitter.disabled = true
    this.dispatch("start")

    queue.enqueue(async () => {
      let response, outcome
      try {
        response = await window.fetch(form.action, {
          method: "POST",
          body,
          headers: {
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
            "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          }
        })
        outcome = submitOutcome({
          status: response.status,
          redirected: response.redirected,
          contentType: response.headers.get("Content-Type")
        })
      } catch {
        outcome = "fail"
      }
      if (outcome === "render") window.Turbo.renderStreamMessage(await response.text())
      if (outcome === "visit") window.Turbo.visit(response.url)

      const success = outcome !== "fail"
      if (submitter) submitter.disabled = false
      this.dispatch("end", { detail: { success } })

      if (!success && this.reportFailureValue) {
        form.reset()
        window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("forms.save_failed") } }))
      }
    })
  }
}
