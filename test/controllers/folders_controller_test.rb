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
    # move_to! runs ahead of the client's full-order reindex, so the moved
    # folder must land exactly where folder_ids puts it.
    assert_equal 1, @folder.position
  end

  test "move 404s for another user's folder, and moves nothing" do
    theirs = users(:two).notebooks.create!(name: "Theirs")
    foreign_folder = theirs.folders.create!(name: "Foreign")

    patch move_notebook_folder_url(@notebook, foreign_folder), params: { target_notebook_id: @notebook.id, folder_ids: [ @folder.id ] }

    assert_response :not_found
    assert_equal theirs, foreign_folder.reload.notebook
  end

  test "move 404s for another user's notebook as the target, and moves nothing" do
    foreign_notebook = users(:two).notebooks.create!(name: "Theirs")

    patch move_notebook_folder_url(@notebook, @folder), params: { target_notebook_id: foreign_notebook.id, folder_ids: [ @folder.id ] }

    assert_response :not_found
    assert_equal @notebook, @folder.reload.notebook
  end

  test "renaming a folder sets the renamed toast" do
    patch notebook_folder_url(@notebook, @folder), params: { name: "改名フォルダ" }
    follow_redirect!

    assert_select "[data-controller=flash-toast][data-flash-toast-message-value=?]", I18n.t("home.folders.flash.renamed")
    assert_select "#folders-list", text: /改名フォルダ/
  end

  test "move into a notebook whose folder shares the moved folder's position lands at the requested slot" do
    { "Movable" => :first, "移動するフォルダ" => :last }.each do |name, slot|
      source = users(:one).notebooks.create!(name: "Source #{name}")
      moved = source.folders.create!(name: name, position: 1)
      left_behind = source.folders.create!(name: "Left behind", position: 2)
      target = users(:one).notebooks.create!(name: "Target #{name}")
      existing = [ target.folders.create!(name: "T1", position: 1), target.folders.create!(name: "T2", position: 2) ]
      order = slot == :first ? [ moved, *existing ] : [ *existing, moved ]

      patch move_notebook_folder_url(source, moved), params: { target_notebook_id: target.id, folder_ids: order.map(&:id) }

      assert_response :success
      assert_equal order, target.folders.reload.to_a
      assert_equal [ 1, 2, 3 ], target.folders.pluck(:position)
      assert_equal [ [ left_behind.id, 1 ] ], source.folders.pluck(:id, :position)
    end
  end
end
