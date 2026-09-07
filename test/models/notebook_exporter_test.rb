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
end
