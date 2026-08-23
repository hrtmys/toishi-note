import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"

// Drag-and-drop for Organize — the one part pulling in SortableJS,
// lazily loaded via connect(). esbuild's ".digested" chunk names keep
// dynamic-import chunks from being 404'd by Propshaft.
export default class extends Controller {
  static targets = [ "notebookList", "folderList", "noteList" ]

  connect() {
    import("sortablejs").then(({ default: Sortable }) => {
      this.Sortable = Sortable
      this.initializeAllLists()
    })
  }

  // Stimulus calls these for every matching element, including ones
  // inserted later by a turbo_stream update. If Sortable hasn't loaded
  // yet, this is a no-op — the sweep in connect() picks it up instead.
  notebookListTargetConnected(element) { this.bindNotebookList(element) }
  folderListTargetConnected(element) { this.bindFolderList(element) }
  noteListTargetConnected(element) { this.bindNoteList(element) }

  initializeAllLists() {
    this.notebookListTargets.forEach((element) => this.bindNotebookList(element))
    this.folderListTargets.forEach((element) => this.bindFolderList(element))
    this.noteListTargets.forEach((element) => this.bindNoteList(element))
  }

  bindNotebookList(element) {
    if (!this.Sortable) return

    new this.Sortable(element, {
      handle: ".organize-drag-handle",
      forceFallback: true,
      onEnd: (event) => {
        if (event.oldIndex === event.newIndex) return

        const notebookIds = Array.from(element.children).map((li) => li.dataset.notebookId)
        this.patch("/notebooks/reorder", { notebook_ids: notebookIds })
      }
    })
  }

  bindFolderList(element) {
    if (!this.Sortable) return

    // Shared group name lets a folder drag between any two notebooks'
    // lists, not just reorder within its own.
    new this.Sortable(element, {
      group: "organize-folders",
      handle: ".organize-drag-handle",
      forceFallback: true,
      onEnd: (event) => {
        if (event.to === event.from && event.oldIndex === event.newIndex) return

        const folderId = event.item.dataset.folderId
        const sourceNotebookId = event.from.dataset.notebookId
        const targetNotebookId = event.to.dataset.notebookId
        const folderIds = Array.from(event.to.children).map((li) => li.dataset.folderId)

        this.patch(`/notebooks/${sourceNotebookId}/folders/${folderId}/move`, {
          target_notebook_id: targetNotebookId,
          folder_ids: folderIds
        })
      }
    })
  }

  bindNoteList(element) {
    if (!this.Sortable) return

    new this.Sortable(element, {
      group: "organize-notes",
      handle: ".organize-drag-handle",
      forceFallback: true,
      onEnd: (event) => {
        // Reparent-only — a note's position within a folder is never
        // persisted (pin + sort own that), so a same-folder drag is a
        // pure no-op here even though Sortable visually reorders it.
        if (event.to === event.from) return

        const noteId = event.item.dataset.noteId
        const targetFolderId = event.to.dataset.folderId

        this.patch(`/notes/${noteId}/move`, { target_folder_id: targetFolderId })
      }
    })
  }

  patch(url, body) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
      },
      body: JSON.stringify(body)
    }).then((response) => {
      if (!response.ok) this.handleFailure()
    }).catch(() => this.handleFailure())
  }

  // The DOM already visually reflects the drag by the time this fires —
  // simplest correct recovery is discarding that state and reloading
  // from the server rather than hand-rolling an undo.
  handleFailure() {
    window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: t("organize.move_failed") } }))
    window.location.reload()
  }
}
