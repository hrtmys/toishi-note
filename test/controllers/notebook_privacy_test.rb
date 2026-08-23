require "test_helper"

# Notebooks are private, no sharing model. Locks in that a signed-in
# user can never read/write another account's data by guessing an id.
class NotebookPrivacyTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "can't update another account's notebook" do
    patch notebook_url(notebooks(:two)), params: { name: "Hijacked" }
    assert_response :not_found
    assert_not_equal "Hijacked", notebooks(:two).reload.name
  end

  test "can't destroy another account's notebook" do
    assert_no_difference("Notebook.count") do
      delete notebook_url(notebooks(:two))
    end
    assert_response :not_found
  end

  test "can't create a folder under another account's notebook" do
    assert_no_difference("Folder.count") do
      post notebook_folders_url(notebooks(:two)), params: { name: "Sneaky Folder" }
    end
    assert_response :not_found
  end

  test "can't update or destroy a folder in another account's notebook" do
    patch notebook_folder_url(notebooks(:two), folders(:two)), params: { name: "Hijacked" }
    assert_response :not_found
    assert_not_equal "Hijacked", folders(:two).reload.name

    assert_no_difference("Folder.count") do
      delete notebook_folder_url(notebooks(:two), folders(:two))
    end
    assert_response :not_found
  end

  test "can't create a note in another account's folder" do
    assert_no_difference("Note.count") do
      post notes_url, params: { folder_id: folders(:two).id, note_type: "md" }
    end
    assert_response :not_found
  end

  test "can't update, destroy, or read another account's note" do
    patch note_url(notes(:two)), params: { note: { title: "Hijacked" } }, as: :turbo_stream
    assert_response :not_found
    assert_not_equal "Hijacked", notes(:two).reload.title

    assert_no_difference("Note.count") do
      delete note_url(notes(:two))
    end
    assert_response :not_found
  end

  test "reorder ignores/rejects a foreign notebook id mixed into the list" do
    original_position = notebooks(:one).position

    patch reorder_notebooks_url, params: { notebook_ids: [ notebooks(:one).id, notebooks(:two).id ] }

    assert_response :not_found
    assert_equal original_position, notebooks(:one).reload.position
  end

  test "can't move a folder that belongs to another account's notebook" do
    patch move_notebook_folder_url(notebooks(:two), folders(:two)), params: { target_notebook_id: notebooks(:one).id, folder_ids: [ folders(:two).id ] }
    assert_response :not_found
    assert_equal notebooks(:two), folders(:two).reload.notebook
  end

  test "can't move a folder into another account's notebook" do
    patch move_notebook_folder_url(notebooks(:one), folders(:one)), params: { target_notebook_id: notebooks(:two).id, folder_ids: [ folders(:one).id ] }
    assert_response :not_found
    assert_equal notebooks(:one), folders(:one).reload.notebook
  end

  test "can't move another account's note" do
    patch move_note_url(notes(:two)), params: { target_folder_id: folders(:one).id }
    assert_response :not_found
  end

  test "can't move a note into another account's folder" do
    note = folders(:one).notes.create!(notebook: notebooks(:one), title: "Mine", note_type: "md")

    patch move_note_url(note), params: { target_folder_id: folders(:two).id }

    assert_response :not_found
    assert_equal folders(:one), note.reload.folder
  end

  test "can't create, update, or destroy todo items on another account's note" do
    assert_no_difference("TodoItem.count") do
      post note_todo_items_url(notes(:two)), params: { content: "Sneaky task" }, as: :turbo_stream
    end
    assert_response :not_found

    patch note_todo_item_url(notes(:two), todo_items(:two)), params: { is_checked: true }, as: :turbo_stream
    assert_response :not_found
    assert_equal false, todo_items(:two).reload.is_checked

    assert_no_difference("TodoItem.count") do
      delete note_todo_item_url(notes(:two), todo_items(:two)), as: :turbo_stream
    end
    assert_response :not_found
  end

  test "can't create or destroy scrap items on another account's note" do
    assert_no_difference("ScrapItem.count") do
      post note_scrap_items_url(notes(:two)), params: { content: "Sneaky scrap" }, as: :turbo_stream
    end
    assert_response :not_found

    assert_no_difference("ScrapItem.count") do
      delete note_scrap_item_url(notes(:two), scrap_items(:two)), as: :turbo_stream
    end
    assert_response :not_found
  end

  test "the sidebar only lists the signed-in account's own notebooks" do
    get root_url

    assert_select "a", text: notebooks(:one).name
    assert_select "a", text: notebooks(:two).name, count: 0
  end

  test "a fresh notebook is owned by whoever created it" do
    post notebooks_url, params: { name: "My New Notebook" }

    assert_equal users(:one), Notebook.find_by(name: "My New Notebook").user
  end
end
