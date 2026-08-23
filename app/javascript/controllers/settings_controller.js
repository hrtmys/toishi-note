import { Controller } from "@hotwired/stimulus"

// Settings toggles fade the corresponding UI in/out immediately (no
// reload), then persist the choice in the background.
export default class extends Controller {
  static values = { url: String }

  toggleFab(event) {
    document.querySelectorAll("[data-editor-fab-section='ai-formatting']").forEach((el) => {
      el.classList.toggle("d-none", !event.target.checked)
    })

    this.updateFabVisibility()
    this.save("editor_fab_enabled", event.target.checked)
  }

  toggleCompare(event) {
    document.querySelectorAll("[data-editor-fab-section='compare']").forEach((el) => {
      el.classList.toggle("d-none", !event.target.checked)
    })

    this.updateFabVisibility()
    this.save("compare_enabled", event.target.checked)
  }

  toggleTablePaste(event) {
    document.querySelectorAll("[data-editor-fab-section='table-paste']").forEach((el) => {
      el.classList.toggle("d-none", !event.target.checked)
    })

    this.updateFabVisibility()
    this.save("table_paste_enabled", event.target.checked)
  }

  // The floating button is shared between three independent features —
  // visible as soon as any one is on, hidden only once all three are off.
  updateFabVisibility() {
    const fabEnabled = document.getElementById("editorFabToggle")?.checked
    const compareEnabled = document.getElementById("compareToggle")?.checked
    const tablePasteEnabled = document.getElementById("tablePasteToggle")?.checked

    document.querySelectorAll("[data-editor-fab]").forEach((el) => {
      el.classList.toggle("d-none", !(fabEnabled || compareEnabled || tablePasteEnabled))
    })
  }

  // Doesn't need to touch anything visible — it only affects how the next
  // pasted/dropped image gets processed server-side.
  toggleKeepOriginalImages(event) {
    this.save("keep_original_images", event.target.checked)
  }

  // The one setting that's *not* fade-in-place: already-rendered text
  // can't be live-translated, so a reload applies it. Waits for the save
  // to land first, or an immediate reload would cancel the request.
  changeLocale(event) {
    this.save("locale", event.target.value).finally(() => window.location.reload())
  }

  save(field, value) {
    // Forgery protection (and this meta tag) is off in test — guard
    // rather than let a null dereference break the fetch below.
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    return fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
      },
      body: JSON.stringify({ [field]: value }),
    }).catch((error) => console.error("Failed to save settings", error))
  }
}
