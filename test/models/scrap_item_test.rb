require "test_helper"

class ScrapItemTest < ActiveSupport::TestCase
  setup do
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Scrap Note", note_type: "scrap")
  end

  test "valid with a note and content" do
    item = @note.scrap_items.new(content: "Some scrap text")
    assert item.valid?
  end

  test "invalid without a note" do
    item = ScrapItem.new(content: "Orphan scrap")
    assert_not item.valid?
    assert_includes item.errors[:note], "must exist"
  end

  test "invalid without content" do
    item = @note.scrap_items.new(content: nil)
    assert_not item.valid?
  end

  test "invalid with blank content" do
    item = @note.scrap_items.new(content: "")
    assert_not item.valid?
  end

  test "position is assigned automatically, appended after existing siblings" do
    first = @note.scrap_items.create!(content: "First")
    second = @note.scrap_items.create!(content: "Second")

    assert_equal 1, first.position
    assert_equal 2, second.position
  end

  test "source is optional" do
    item = @note.scrap_items.new(content: "Some scrap text")
    assert item.valid?
    assert_nil item.source
  end
end
