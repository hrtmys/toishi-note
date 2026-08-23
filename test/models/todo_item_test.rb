require "test_helper"

class TodoItemTest < ActiveSupport::TestCase
  setup do
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Todo Note", note_type: "todo")
  end

  test "valid with content" do
    item = @note.todo_items.new(content: "Buy milk")
    assert item.valid?
  end

  test "invalid without content" do
    item = @note.todo_items.new(content: nil)
    assert_not item.valid?
  end

  test "invalid with blank content" do
    item = @note.todo_items.new(content: "")
    assert_not item.valid?
  end

  test "is_checked defaults to false for a new record" do
    item = @note.todo_items.new(content: "Buy milk")
    assert_equal false, item.is_checked
  end

  test "is_checked can be explicitly set to true on initialize" do
    item = @note.todo_items.new(content: "Buy milk", is_checked: true)
    assert_equal true, item.is_checked
  end

  test "invalid without a note" do
    item = TodoItem.new(content: "Orphan task")
    assert_not item.valid?
    assert_includes item.errors[:note], "must exist"
  end

  test "position is assigned automatically, appended after existing siblings" do
    first = @note.todo_items.create!(content: "First")
    second = @note.todo_items.create!(content: "Second")

    assert_equal 1, first.position
    assert_equal 2, second.position
  end

  test "position numbering is scoped to the note, not global" do
    other_note = @folder.notes.create!(notebook: @notebook, title: "Other Todo Note", note_type: "todo")

    @note.todo_items.create!(content: "In first note")
    item_in_other_note = other_note.todo_items.create!(content: "In other note")

    assert_equal 1, item_in_other_note.position
  end

  test "an explicitly assigned position is not overwritten" do
    item = @note.todo_items.create!(content: "Pre-positioned", position: 99)
    assert_equal 99, item.position
  end

  test "note.todo_items is ordered by position, not creation order" do
    created_first_but_positioned_last = @note.todo_items.create!(content: "Created first", position: 2)
    created_second_but_positioned_first = @note.todo_items.create!(content: "Created second", position: 1)

    assert_equal [ created_second_but_positioned_first, created_first_but_positioned_last ], @note.todo_items.to_a
  end

  test "due_date is optional" do
    item = @note.todo_items.new(content: "No due date")
    assert item.valid?
    assert_nil item.due_date
  end

  test "overdue? is false without a due date" do
    item = @note.todo_items.create!(content: "No due date")
    assert_not item.overdue?
  end

  test "overdue? is true for a past due date that isn't checked" do
    item = @note.todo_items.create!(content: "Late", due_date: 1.day.ago.to_date)
    assert item.overdue?
  end

  test "overdue? is false for a past due date that's already checked" do
    item = @note.todo_items.create!(content: "Late but done", due_date: 1.day.ago.to_date, is_checked: true)
    assert_not item.overdue?
  end

  test "overdue? is false for a future due date" do
    item = @note.todo_items.create!(content: "Not yet", due_date: 1.day.from_now.to_date)
    assert_not item.overdue?
  end

  test "overdue? is false for today's due date" do
    item = @note.todo_items.create!(content: "Due today", due_date: Date.current)
    assert_not item.overdue?
  end
end
