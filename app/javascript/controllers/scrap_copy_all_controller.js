import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

// Concatenates every scrap item's raw content (in position order, same
// separator as Export) and copies it in one shot — built for pasting the
// whole context back into an AI chat.
export default class extends Controller {
  static targets = [ "item" ]

  async copyAll() {
    const text = this.itemTargets.map((item) => item.dataset.content).join("\n\n---\n\n")

    try {
      await navigator.clipboard.writeText(text)
      window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("copied") } }))
    } catch (error) {
      console.error("Failed to copy scrap items", error)
    }
  }
}
