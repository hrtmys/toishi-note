require "test_helper"

class NotebooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
  end

  test "should create notebook" do
    assert_difference("Notebook.count") do
      post notebooks_url, params: { name: "New Notebook" }
    end
    assert_redirected_to %r{\A#{root_url}}
  end

  test "should update notebook" do
    patch notebook_url(@notebook), params: { name: "Renamed Notebook" }
    assert_redirected_to root_url(notebook_id: @notebook.id)
    @notebook.reload
    assert_equal "Renamed Notebook", @notebook.name
  end

  test "should destroy notebook" do
    assert_difference("Notebook.count", -1) do
      delete notebook_url(@notebook)
    end
    assert_redirected_to root_url
  end

  test "create/update/destroy redirect back into Organize, to the request's own context, when organize is present" do
    other_notebook = users(:one).notebooks.create!(name: "Context Notebook")

    post notebooks_url, params: { name: "New Notebook", organize: true, notebook_id: other_notebook.id }
    assert_redirected_to root_url(organize: true, notebook_id: other_notebook.id)

    patch notebook_url(@notebook), params: { name: "Renamed", organize: true, notebook_id: other_notebook.id }
    assert_redirected_to root_url(organize: true, notebook_id: other_notebook.id)

    delete notebook_url(@notebook), params: { organize: true, notebook_id: other_notebook.id }
    assert_redirected_to root_url(organize: true, notebook_id: other_notebook.id)
  end

  test "without organize present, redirects to the plain editor exactly as before" do
    post notebooks_url, params: { name: "New Notebook" }
    assert_redirected_to root_url(notebook_id: Notebook.last.id)
  end

  test "exports a zip with one .md file per note, organized by folder" do
    folder = @notebook.folders.create!(name: "Folder A")
    folder.notes.create!(notebook: @notebook, title: "My Note", note_type: "md", content: "Hello")

    get export_notebook_url(@notebook)
    assert_response :success
    assert_equal "application/zip", response.media_type

    entries = zip_entries(response.body)
    assert_equal [ "Folder A/My Note.md" ], entries.keys
    assert_equal "Hello", entries["Folder A/My Note.md"]
  end

  test "numbers duplicate note titles within the same folder instead of overwriting" do
    folder = @notebook.folders.create!(name: "Folder A")
    folder.notes.create!(notebook: @notebook, title: "Same Title", note_type: "md", content: "First")
    folder.notes.create!(notebook: @notebook, title: "Same Title", note_type: "md", content: "Second")

    get export_notebook_url(@notebook)

    entries = zip_entries(response.body)
    assert_equal [ "Folder A/Same Title (2).md", "Folder A/Same Title.md" ], entries.keys.sort
    assert_equal [ "First", "Second" ], entries.values.sort
  end

  test "export only ever includes the current user's own notebook" do
    other_notebook = notebooks(:two) # belongs to users(:two)
    get export_notebook_url(other_notebook)
    assert_response :not_found
  end

  test "reorder resequences notebooks in the given order" do
    # users(:one) owns notebooks(:one) besides @notebook — the full id
    # list must include every notebook, since reposition! requires an
    # exact match.
    all_ids = users(:one).notebooks.pluck(:id)

    patch reorder_notebooks_url, params: { notebook_ids: all_ids.reverse }

    assert_response :success
    reversed = users(:one).notebooks.reload.order(:position).pluck(:id)
    assert_equal all_ids.reverse, reversed
  end

  test "reorder 404s (and writes nothing) when the id list doesn't match this account's notebooks" do
    other_notebooks_notebook = notebooks(:two) # belongs to users(:two)
    original_position = @notebook.position

    patch reorder_notebooks_url, params: { notebook_ids: [ @notebook.id, other_notebooks_notebook.id ] }

    assert_response :not_found
    assert_equal original_position, @notebook.reload.position
  end

  private

  def zip_entries(zip_body)
    entries = {}
    Zip::InputStream.open(StringIO.new(zip_body)) do |io|
      while (entry = io.get_next_entry)
        entries[entry.name] = io.read
      end
    end
    entries
  end
end
