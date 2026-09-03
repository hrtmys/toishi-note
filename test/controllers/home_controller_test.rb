require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get index with no notebooks at all" do
    Notebook.destroy_all
    get root_url
    assert_response :success
  end

  test "defaults to the first notebook when no notebook_id is given" do
    notebook = users(:one).notebooks.create!(name: "First Notebook")
    get root_url
    assert_response :success
    assert_select "a#sidebarMenuLabel", text: /Toishi Note/
  end

  test "selects the requested notebook, folder and note via params" do
    notebook = users(:one).notebooks.create!(name: "Chosen Notebook")
    folder = notebook.folders.create!(name: "Chosen Folder")
    note = folder.notes.create!(notebook: notebook, title: "Chosen Note", note_type: "md")

    get root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)

    assert_response :success
    assert_select "input[value=?]", note.title
  end

  test "orders notes with pinned ones first, then newest-updated" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    folder = notebook.folders.create!(name: "Folder")
    older = folder.notes.create!(notebook: notebook, title: "Older", note_type: "md", updated_at: 2.days.ago)
    newer = folder.notes.create!(notebook: notebook, title: "Newer", note_type: "md", updated_at: 1.day.ago)
    pinned_but_oldest = folder.notes.create!(notebook: notebook, title: "Pinned", note_type: "md", updated_at: 3.days.ago, is_pinned: true)

    get root_url(notebook_id: notebook.id, folder_id: folder.id)

    assert_response :success
    positions = [ pinned_but_oldest, newer, older ].map { |note| response.body.index(note.title) }
    assert_equal positions.sort, positions
  end

  test "opening a note records last_viewed_at without touching updated_at" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    folder = notebook.folders.create!(name: "Folder")
    note = folder.notes.create!(notebook: notebook, title: "Note", note_type: "md")
    original_updated_at = note.updated_at

    travel_to 1.hour.from_now do
      get root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)
    end

    note.reload
    assert_in_delta 1.hour.from_now.to_i, note.last_viewed_at.to_i, 5
    # Viewing is not editing — see PaletteController's own comment on why
    # this must stay update_column, never #touch or #update.
    assert_equal original_updated_at.to_i, note.updated_at.to_i
  end

  test "not opening a specific note leaves last_viewed_at on every note untouched" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    folder = notebook.folders.create!(name: "Folder")
    note = folder.notes.create!(notebook: notebook, title: "Note", note_type: "md")

    get root_url(notebook_id: notebook.id, folder_id: folder.id)

    assert_nil note.reload.last_viewed_at
  end

  test "visiting a notebook and folder remembers them as the user's last position" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    folder = notebook.folders.create!(name: "Folder")

    get root_url(notebook_id: notebook.id, folder_id: folder.id)

    users(:one).reload
    assert_equal notebook.id, users(:one).last_notebook_id
    assert_equal folder.id, users(:one).last_folder_id
  end

  test "a later visit with no params falls back to the remembered notebook and folder" do
    users(:one).notebooks.create!(name: "First Notebook")
    remembered_notebook = users(:one).notebooks.create!(name: "Remembered Notebook")
    remembered_folder = remembered_notebook.folders.create!(name: "Remembered Folder")
    users(:one).update_columns(last_notebook_id: remembered_notebook.id, last_folder_id: remembered_folder.id)

    get root_url

    assert_response :success
    assert_select "li.bg-secondary", text: /#{Regexp.escape(remembered_folder.name)}/
  end

  test "a remembered folder belonging to a different notebook is ignored" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    other_notebook = users(:one).notebooks.create!(name: "Other Notebook")
    other_folder = other_notebook.folders.create!(name: "Other Folder")
    own_folder = notebook.folders.create!(name: "Own Folder")
    users(:one).update_columns(last_notebook_id: notebook.id, last_folder_id: other_folder.id)

    get root_url(notebook_id: notebook.id)

    assert_response :success
    users(:one).reload
    assert_equal own_folder.id, users(:one).last_folder_id
  end
end
