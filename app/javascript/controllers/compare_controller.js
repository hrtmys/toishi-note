import { Controller } from "@hotwired/stimulus"
import { renderDiffHtml } from "../lib/text_diff"

// The Compare modal's contents: two independent Before/After text boxes,
// diffed live via `diffWordsWithSpace`. Content loads in either from the
// FAB (compare_launcher_controller.js) or Quick Formatting (text_format_controller.js).
export default class extends Controller {
  static targets = ["before", "after", "output", "empty", "unchanged"]

  connect() {
    this.render()
  }

  // Quick Formatting (text_format_controller.js) dispatches this after
  // applying a transform, replacing both sides at once.
  load(event) {
    this.beforeTarget.value = event.detail.before
    this.afterTarget.value = event.detail.after
    this.render()
  }

  // The FAB's "Set as Before"/"Set as After" (compare_launcher_controller.js)
  // dispatch this, replacing just the one side named in event.detail.side.
  stage(event) {
    const { side, value } = event.detail
    const target = side === "before" ? this.beforeTarget : this.afterTarget

    target.value = value
    this.render()
  }

  clear() {
    this.beforeTarget.value = ""
    this.afterTarget.value = ""
    this.render()
  }

  render() {
    const before = this.beforeTarget.value
    const after = this.afterTarget.value
    const empty = !before && !after

    this.emptyTarget.classList.toggle("d-none", !empty)
    this.unchangedTarget.classList.toggle("d-none", empty || before !== after)

    this.outputTarget.innerHTML = empty ? "" : renderDiffHtml(before, after)
  }
}
