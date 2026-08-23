require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Test Note", note_type: "md")
  end

  test "should create note" do
    assert_difference("Note.count") do
      post notes_url, params: { folder_id: @folder.id, note_type: "md" }
    end
    assert_redirected_to %r{\A#{root_url}}
  end

  test "should create note with default title based on note_type" do
    post notes_url, params: { folder_id: @folder.id, note_type: "todo" }
    assert_equal Note.default_title_for("todo"), Note.last.title
  end

  test "should create note with default note_type when not given" do
    post notes_url, params: { folder_id: @folder.id }
    assert_equal "md", Note.last.note_type
  end

  test "should update note" do
    patch note_url(@note), params: { note: { title: "Updated Note" } }, as: :turbo_stream
    assert_response :success
    @note.reload
    assert_equal "Updated Note", @note.title
  end

  test "reports the new lock_version after a successful save, so the next save can submit it" do
    patch note_url(@note), params: { note: { title: "Updated Note", lock_version: @note.lock_version } }, as: :turbo_stream
    assert_response :success
    assert_equal @note.reload.lock_version.to_s, response.headers["X-Note-Lock-Version"]
  end

  test "a stale lock_version is rejected with 409, and never applies the stale write" do
    # Simulates the actual bug: two devices both loaded this note, one
    # saved first (bumping lock_version), the second's PUT still carries
    # the version it originally loaded.
    original_version = @note.lock_version
    @note.update!(content: "Saved from device A")

    patch note_url(@note), params: { note: { content: "Saved from device B", lock_version: original_version } }, as: :turbo_stream

    assert_response :conflict
    assert_equal "Saved from device A", @note.reload.content
  end

  test "a 409 still reports the current lock_version, so a deliberate retry can succeed" do
    original_version = @note.lock_version
    @note.update!(content: "Saved from device A")

    patch note_url(@note), params: { note: { content: "Saved from device B", lock_version: original_version } }, as: :turbo_stream
    assert_response :conflict
    reported_version = response.headers["X-Note-Lock-Version"]
    assert_equal @note.reload.lock_version.to_s, reported_version

    # A deliberate retry ("Keep mine") with the version the 409 just
    # reported succeeds and genuinely overwrites the other device's save —
    # that's the whole point of asking rather than resolving silently.
    patch note_url(@note), params: { note: { content: "Saved from device B", lock_version: reported_version } }, as: :turbo_stream
    assert_response :success
    assert_equal "Saved from device B", @note.reload.content
  end

  test "omitting lock_version entirely (e.g. Organize's rename form) still saves normally" do
    patch note_url(@note), params: { note: { title: "Renamed via Organize" } }, as: :turbo_stream
    assert_response :success
    assert_equal "Renamed via Organize", @note.reload.title
  end

  test "submitting a title through the update action marks it customized, so later content saves don't override it" do
    @note.update!(content: "") # start from a note with no content to auto-title from yet

    patch note_url(@note), params: { note: { title: "A Real Title" } }, as: :turbo_stream
    assert @note.reload.title_customized?

    patch note_url(@note), params: { note: { content: "First line of content" } }, as: :turbo_stream
    assert_equal "A Real Title", @note.reload.title
  end

  test "a content-only save never marks the title customized" do
    # @note (from setup) already has a real, explicit title, which itself
    # already marks it customized — start from a genuinely blank-titled
    # note instead, so this test actually exercises the content-only case.
    note = @folder.notes.create!(notebook: @notebook, title: "", note_type: "md")
    assert_not note.title_customized?

    patch note_url(note), params: { note: { content: "Just typing" } }, as: :turbo_stream
    assert_not note.reload.title_customized?
  end

  test "blanking the title falls back to the default placeholder instead of failing" do
    patch note_url(@note), params: { note: { title: "" } }, as: :turbo_stream
    assert_response :success
    @note.reload
    assert_equal Note.default_title_for("md"), @note.title
  end

  test "should pin and unpin a note" do
    patch note_url(@note), params: { note: { is_pinned: true } }, as: :json
    assert_response :success
    assert @note.reload.is_pinned?

    patch note_url(@note), params: { note: { is_pinned: false } }, as: :json
    assert_response :success
    assert_not @note.reload.is_pinned?
  end

  test "should destroy note" do
    assert_difference("Note.count", -1) do
      delete note_url(@note)
    end
    assert_redirected_to %r{\A#{root_url}}
  end

  test "destroy redirects back into Organize, to the request's own context, when organize is present" do
    delete note_url(@note), params: { organize: true, notebook_id: @notebook.id, folder_id: @folder.id }
    assert_redirected_to root_url(organize: true, notebook_id: @notebook.id, folder_id: @folder.id)
  end

  test "a plain (non-Turbo) form submission to update renames the note and redirects — Organize's rename control" do
    patch note_url(@note), params: { note: { title: "Renamed via Organize" } }
    assert_redirected_to root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    assert_equal "Renamed via Organize", @note.reload.title
  end

  test "a plain form submission to update redirects back into Organize when organize is present" do
    patch note_url(@note), params: { note: { title: "Renamed via Organize" }, organize: true, notebook_id: @notebook.id, folder_id: @folder.id }
    assert_redirected_to root_url(organize: true, notebook_id: @notebook.id, folder_id: @folder.id)
  end

  test "move reparents the note to the destination folder and derives notebook_id from it" do
    other_notebook = users(:one).notebooks.create!(name: "Other Notebook")
    other_folder = other_notebook.folders.create!(name: "Other Folder")

    patch move_note_url(@note), params: { target_folder_id: other_folder.id }

    assert_response :success
    @note.reload
    assert_equal other_folder, @note.folder
    assert_equal other_notebook, @note.notebook, "notebook_id must be derived from the destination folder, not sent by the client"
  end

  test "move within the same notebook only changes the folder" do
    other_folder = @notebook.folders.create!(name: "Other Folder In Same Notebook")

    patch move_note_url(@note), params: { target_folder_id: other_folder.id }

    assert_response :success
    @note.reload
    assert_equal other_folder, @note.folder
    assert_equal @notebook, @note.notebook
  end

  test "exports a note as a downloadable .md file" do
    @note.update!(content: "# Hello")

    get export_note_url(@note)
    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_equal "# Hello", response.body
  end

  test "export only ever includes the current user's own note" do
    other_note = notes(:two) # belongs to users(:two)
    get export_note_url(other_note)
    assert_response :not_found
  end

  test "update is protected by CSRF verification (no longer skipped)" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    begin
      patch note_url(@note),
        params: { note: { title: "Forged Update" } },
        headers: { "X-CSRF-Token" => "invalid-token" },
        as: :turbo_stream
      assert_response :unprocessable_entity
      @note.reload
      assert_not_equal "Forged Update", @note.title
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end
end
