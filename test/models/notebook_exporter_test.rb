require "test_helper"

class NotebookExporterTest < ActiveSupport::TestCase
  test "a folder or note literally named .. never produces a .. path segment in the zip" do
    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "..")
    folder.notes.create!(notebook: notebook, title: "..", note_type: "md", content: "hello")

    zip_data = NotebookExporter.new(notebook).to_zip

    entry_names = []
    Zip::InputStream.open(StringIO.new(zip_data)) do |io|
      while (entry = io.get_next_entry)
        entry_names << entry.name
      end
    end

    assert entry_names.any?, "expected at least one entry in the zip"
    entry_names.each do |name|
      name.split("/").each do |segment|
        assert_not_equal "..", segment, "zip entry #{name.inspect} contains a .. path segment"
      end
    end
  end

  # #to_markdown lazily loads todo_items/scrap_items per note when the note
  # is a todo/scrap type. Without eager-loading those associations
  # alongside notes, exporting would issue one extra query per todo/scrap
  # note (an N+1). Count queries against those two tables directly, so the
  # assertion holds regardless of how many notes are in the fixture.
  test "exporting does not issue one todo_items/scrap_items query per note (no N+1)" do
    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "Folder")

    3.times do |i|
      todo_note = folder.notes.create!(notebook: notebook, title: "Todo #{i}", note_type: "todo")
      todo_note.todo_items.create!(content: "Item")

      scrap_note = folder.notes.create!(notebook: notebook, title: "Scrap #{i}", note_type: "scrap")
      scrap_note.scrap_items.create!(content: "Content")
    end

    todo_scrap_queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      todo_scrap_queries += 1 if sql.match?(/\b(todo_items|scrap_items)\b/) && !payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      NotebookExporter.new(notebook).to_zip
    end

    # One preload query per association (todo_items, scrap_items), not one
    # per note — with 3 todo notes + 3 scrap notes, an N+1 would issue 6.
    assert_operator todo_scrap_queries, :<=, 2,
      "expected todo_items/scrap_items to be eager-loaded (<= 2 queries total), got #{todo_scrap_queries}"
  end
end
