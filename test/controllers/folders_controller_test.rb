require "test_helper"

class FoldersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "should create folder" do
    assert_difference("Folder.count") do
      post notebook_folders_url(@notebook), params: { name: "New Folder" }
    end
    assert_redirected_to %r{\A#{root_url}}
  end

  test "should update folder" do
    patch notebook_folder_url(@notebook, @folder), params: { name: "Renamed Folder" }
    assert_redirected_to root_url(notebook_id: @notebook.id, folder_id: @folder.id)
    @folder.reload
    assert_equal "Renamed Folder", @folder.name
  end

  test "should destroy folder" do
    assert_difference("Folder.count", -1) do
      delete notebook_folder_url(@notebook, @folder)
    end
    assert_redirected_to root_url(notebook_id: @notebook.id)
  end

  test "create/update/destroy redirect back into Organize, to the request's own context, when organize is present" do
    post notebook_folders_url(@notebook), params: { name: "New Folder", organize: true, notebook_id: @notebook.id }
    assert_redirected_to root_url(organize: true, notebook_id: @notebook.id)

    patch notebook_folder_url(@notebook, @folder), params: { name: "Renamed", organize: true, notebook_id: @notebook.id }
    assert_redirected_to root_url(organize: true, notebook_id: @notebook.id)

    delete notebook_folder_url(@notebook, @folder), params: { organize: true, notebook_id: @notebook.id }
    assert_redirected_to root_url(organize: true, notebook_id: @notebook.id)
  end

  test "without organize present, redirects to the plain editor exactly as before" do
    post notebook_folders_url(@notebook), params: { name: "New Folder" }
    assert_redirected_to root_url(notebook_id: @notebook.id, folder_id: Folder.last.id)
  end

  test "move reorders folders within the same notebook" do
    second = @notebook.folders.create!(name: "Second")

    patch move_notebook_folder_url(@notebook, second), params: { target_notebook_id: @notebook.id, folder_ids: [ second.id, @folder.id ] }

    assert_response :success
    assert_equal 1, second.reload.position
    assert_equal 2, @folder.reload.position
    assert_equal @notebook, second.notebook, "a same-notebook move must not change the notebook"
  end

  test "move to a different notebook reparents the folder and cascades to its notes" do
    other_notebook = users(:one).notebooks.create!(name: "Other Notebook")
    note = @folder.notes.create!(notebook: @notebook, title: "Carried Along", note_type: "md")

    patch move_notebook_folder_url(@notebook, @folder), params: { target_notebook_id: other_notebook.id, folder_ids: [ @folder.id ] }

    assert_response :success
    assert_equal other_notebook, @folder.reload.notebook
    assert_equal other_notebook, note.reload.notebook, "the folder's notes must follow via the notebook_id cascade"
  end
end
