import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { folderMoveRequest, noteMoveRequest, notebookReorderRequest } from "../../app/javascript/lib/organize_moves.js"

describe("notebookReorderRequest", () => {
  it("is null when the notebook lands where it started", () => {
    assert.equal(notebookReorderRequest({ oldIndex: 2, newIndex: 2, notebookIds: [ "1", "2", "3" ] }), null)
  })

  it("sends the new order", () => {
    assert.deepEqual(
      notebookReorderRequest({ oldIndex: 0, newIndex: 2, notebookIds: [ "2", "3", "1" ] }),
      { url: "/notebooks/reorder", body: { notebook_ids: [ "2", "3", "1" ] } }
    )
  })
})

describe("folderMoveRequest", () => {
  const base = { folderId: "7", sourceNotebookId: "1", targetNotebookId: "1", folderIds: [ "8", "7" ] }

  it("is null for a drop in place within the same list", () => {
    assert.equal(folderMoveRequest({ ...base, sameList: true, oldIndex: 1, newIndex: 1 }), null)
  })

  it("reorders within a list, sending folder_ids in the new order", () => {
    assert.deepEqual(folderMoveRequest({ ...base, sameList: true, oldIndex: 0, newIndex: 1 }), {
      url: "/notebooks/1/folders/7/move",
      body: { target_notebook_id: "1", folder_ids: [ "8", "7" ] }
    })
  })

  it("moves to another notebook even at the same index", () => {
    const request = folderMoveRequest({ ...base, targetNotebookId: "2", sameList: false, oldIndex: 0, newIndex: 0, folderIds: [ "7", "9" ] })
    assert.deepEqual(request, {
      url: "/notebooks/1/folders/7/move",
      body: { target_notebook_id: "2", folder_ids: [ "7", "9" ] }
    })
  })
})

describe("noteMoveRequest", () => {
  it("is null within the same folder, since note position is never persisted", () => {
    assert.equal(noteMoveRequest({ noteId: "5", targetFolderId: "3", sameList: true }), null)
  })

  it("reparents to the target folder", () => {
    assert.deepEqual(noteMoveRequest({ noteId: "5", targetFolderId: "4", sameList: false }), {
      url: "/notes/5/move",
      body: { target_folder_id: "4" }
    })
  })
})
