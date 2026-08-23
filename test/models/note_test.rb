require "test_helper"

class NoteTest < ActiveSupport::TestCase
  setup do
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "valid with a title and note_type" do
    note = @folder.notes.new(notebook: @notebook, title: "My Note", note_type: "md")
    assert note.valid?
  end

  test "a blank title is auto-filled by the before_validation callback, so the note stays valid" do
    note = @folder.notes.new(notebook: @notebook, title: nil, note_type: "md")
    assert note.valid?
    assert_equal Note.default_title_for("md"), note.title
  end

  test "invalid without a note_type" do
    note = @folder.notes.new(notebook: @notebook, title: "Has Title", note_type: "")
    assert_not note.valid?
    assert_includes note.errors[:note_type], "can't be blank"
  end

  test "note_type defaults to md for a new record when not set" do
    note = Note.new
    assert_equal "md", note.note_type
  end

  test "is_pinned defaults to false for a new record when not set" do
    note = Note.new
    assert_equal false, note.is_pinned
  end

  test "invalid without a folder" do
    note = @notebook.notes.new(title: "No Folder", note_type: "md")
    assert_not note.valid?
    assert_includes note.errors[:folder], "must exist"
  end

  test "destroying a note destroys its todo_items" do
    note = @folder.notes.create!(notebook: @notebook, title: "Todo Note", note_type: "todo")
    note.todo_items.create!(content: "Buy milk")

    assert_difference("TodoItem.count", -1) do
      note.destroy
    end
  end

  test "destroying a note destroys its scrap_items" do
    note = @folder.notes.create!(notebook: @notebook, title: "Scrap Note", note_type: "scrap")
    note.scrap_items.create!(content: "Some scrap")

    assert_difference("ScrapItem.count", -1) do
      note.destroy
    end
  end

  test "auto-titles a blank md note from the first non-blank line of content" do
    note = @folder.notes.create!(
      notebook: @notebook,
      title: "",
      note_type: "md",
      content: "\n\n# My Heading\nBody text"
    )

    assert_equal "# My Heading", note.title
  end

  test "auto-titles from the first line even when title still holds the default placeholder" do
    note = @folder.notes.create!(
      notebook: @notebook,
      title: Note.default_title_for("md"),
      note_type: "md",
      content: "Fresh content here"
    )

    assert_equal "Fresh content here", note.title
  end

  test "does not override a title the user has already customized" do
    note = @folder.notes.create!(
      notebook: @notebook,
      title: "Custom Title",
      note_type: "md",
      content: "Some other content"
    )

    assert_equal "Custom Title", note.title
  end

  test "auto-titles from the first line under a non-default locale too" do
    # The real bug this replaces: the old check regex-matched only
    # hardcoded Japanese placeholder strings, so an English-locale note
    # never got auto-titled at all. Proven by actually switching locale.
    I18n.with_locale(:en) do
      note = @folder.notes.create!(
        notebook: @notebook,
        title: Note.default_title_for("md"),
        note_type: "md",
        content: "English content here"
      )

      assert_equal "English content here", note.title
    end
  end

  test "a placeholder title surviving a locale switch still gets auto-titled, not mistaken for customized" do
    # The edge case a title==placeholder comparison can't handle: after a
    # locale switch, comparing stored title text against the *new*
    # locale's placeholder would wrongly conclude it was customized.
    note = nil
    I18n.with_locale(:ja) do
      note = @folder.notes.create!(notebook: @notebook, title: "", note_type: "md", content: "")
      assert_equal Note.default_title_for("md"), note.title # sanity: still just the placeholder, in Japanese
    end
    assert_not note.title_customized?

    I18n.with_locale(:en) do
      note.update!(content: "Added after switching locale")
    end

    assert_equal "Added after switching locale", note.title
  end

  test "truncates an auto-derived title to 30 characters" do
    long_line = "あ" * 50
    note = @folder.notes.create!(
      notebook: @notebook,
      title: "",
      note_type: "md",
      content: long_line
    )

    assert_equal 30, note.title.length
    assert note.title.end_with?("...")
  end

  test "falls back to the default placeholder title when title and content are blank" do
    note = @folder.notes.create!(
      notebook: @notebook,
      title: "",
      note_type: "md",
      content: ""
    )

    assert_equal Note.default_title_for("md"), note.title
  end

  test "falls back to the todo placeholder title for blank todo notes" do
    note = @folder.notes.create!(
      notebook: @notebook,
      title: "",
      note_type: "todo",
      content: ""
    )

    assert_equal Note.default_title_for("todo"), note.title
  end

  test "falls back to the scrap placeholder title for blank scrap notes" do
    note = @folder.notes.create!(
      notebook: @notebook,
      title: "",
      note_type: "scrap",
      content: ""
    )

    assert_equal Note.default_title_for("scrap"), note.title
  end

  test "todo_completion_percentage is 0 when there are no todo items" do
    note = @folder.notes.create!(notebook: @notebook, title: "Empty Todo Note", note_type: "todo")
    assert_equal 0, note.todo_completion_percentage
    assert_equal 0, note.todo_items_total_count
    assert_equal 0, note.todo_items_completed_count
  end

  test "todo_completion_percentage reflects checked vs total todo items" do
    note = @folder.notes.create!(notebook: @notebook, title: "Todo Note", note_type: "todo")
    note.todo_items.create!(content: "Done", is_checked: true)
    note.todo_items.create!(content: "Not done yet", is_checked: false)

    assert_equal 2, note.todo_items_total_count
    assert_equal 1, note.todo_items_completed_count
    assert_equal 50, note.todo_completion_percentage
  end

  test "does not auto-title non-md notes from content" do
    note = @folder.notes.create!(
      notebook: @notebook,
      title: "",
      note_type: "todo",
      content: "This should not become the title"
    )

    assert_equal Note.default_title_for("todo"), note.title
  end

  test "to_markdown passes md content through unchanged" do
    note = @folder.notes.create!(notebook: @notebook, title: "MD", note_type: "md", content: "# Heading\n\nBody text")
    assert_equal "# Heading\n\nBody text", note.to_markdown
  end

  test "to_markdown converts a todo note to a GFM checklist" do
    note = @folder.notes.create!(notebook: @notebook, title: "Todo", note_type: "todo")
    note.todo_items.create!(content: "Buy milk")
    note.todo_items.create!(content: "Call plumber", is_checked: true)

    assert_equal "- [ ] Buy milk\n- [x] Call plumber", note.to_markdown
  end

  test "to_markdown appends a due date inline on todo items that have one" do
    note = @folder.notes.create!(notebook: @notebook, title: "Todo", note_type: "todo")
    note.todo_items.create!(content: "Renew passport", due_date: Date.new(2026, 9, 1))

    assert_equal "- [ ] Renew passport (due: 2026-09-01)", note.to_markdown
  end

  test "to_markdown joins scrap items with a --- separator, in position order" do
    note = @folder.notes.create!(notebook: @notebook, title: "Scrap", note_type: "scrap")
    note.scrap_items.create!(content: "First")
    note.scrap_items.create!(content: "Second")

    assert_equal "First\n\n---\n\nSecond", note.to_markdown
  end

  test "export_filename sanitizes filesystem-unsafe characters but keeps Japanese titles intact" do
    note = @folder.notes.create!(notebook: @notebook, title: "経路/計画: どうする?", note_type: "md")
    assert_equal "経路_計画_ どうする_.md", note.export_filename
  end

  test "attach_uploaded_image compresses to WebP by default" do
    note = @folder.notes.create!(notebook: @notebook, title: "MD", note_type: "md")
    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(Rails.root.join("test/fixtures/files/sample_image.png")),
      filename: "sample_image.png",
      type: "image/png"
    )

    image = note.attach_uploaded_image(upload, compress: true)

    assert_equal "image/webp", image.blob.content_type
    assert_equal "sample_image.webp", image.blob.filename.to_s
  end

  test "attach_uploaded_image keeps the original when compress is false" do
    note = @folder.notes.create!(notebook: @notebook, title: "MD", note_type: "md")
    upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(Rails.root.join("test/fixtures/files/sample_image.png")),
      filename: "sample_image.png",
      type: "image/png"
    )

    image = note.attach_uploaded_image(upload, compress: false)

    assert_equal "image/png", image.blob.content_type
    assert_equal "sample_image.png", image.blob.filename.to_s
  end
end
