import { Controller } from "@hotwired/stimulus"
import { t } from "../lib/translations"
import { folderMoveRequest, noteMoveRequest, notebookReorderRequest } from "../lib/organize_moves"

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
        const request = notebookReorderRequest({
          oldIndex: event.oldIndex,
          newIndex: event.newIndex,
          notebookIds: Array.from(element.children).map((li) => li.dataset.notebookId)
        })
        if (request) this.patch(request.url, request.body)
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
        const request = folderMoveRequest({
          folderId: event.item.dataset.folderId,
          sourceNotebookId: event.from.dataset.notebookId,
          targetNotebookId: event.to.dataset.notebookId,
          folderIds: Array.from(event.to.children).map((li) => li.dataset.folderId),
          sameList: event.to === event.from,
          oldIndex: event.oldIndex,
          newIndex: event.newIndex
        })
        if (request) this.patch(request.url, request.body, t("organize.folder_moved"))
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
        const request = noteMoveRequest({
          noteId: event.item.dataset.noteId,
          targetFolderId: event.to.dataset.folderId,
          sameList: event.to === event.from
        })
        if (request) this.patch(request.url, request.body, t("organize.note_moved"))
      }
    })
  }

  // successMessage is omitted for the plain reorder endpoints (notebook
  // reorder within the top-level list) — those aren't one of the CRUD
  // operations that need a confirmation, just a drag landing where it
  // visually already looks like it landed. Folder/note move (a genuine
  // reparent) pass one.
  patch(url, body, successMessage = null) {
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
      if (!response.ok) return this.handleFailure()

      if (successMessage) {
        window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: successMessage } }))
      }
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
