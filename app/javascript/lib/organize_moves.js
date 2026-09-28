export function notebookReorderRequest({ oldIndex, newIndex, notebookIds }) {
  if (oldIndex === newIndex) return null

  return { url: "/notebooks/reorder", body: { notebook_ids: notebookIds } }
}

// A cross-notebook drop is a move even when it lands at the same index.
export function folderMoveRequest({ folderId, sourceNotebookId, targetNotebookId, folderIds, sameList, oldIndex, newIndex }) {
  if (sameList && oldIndex === newIndex) return null

  return {
    url: `/notebooks/${sourceNotebookId}/folders/${folderId}/move`,
    body: { target_notebook_id: targetNotebookId, folder_ids: folderIds }
  }
}

// Reparent-only: a note's position within a folder is never persisted
// (pin + sort own that), so a same-folder drag sends nothing.
export function noteMoveRequest({ noteId, targetFolderId, sameList }) {
  if (sameList) return null

  return { url: `/notes/${noteId}/move`, body: { target_folder_id: targetFolderId } }
}
