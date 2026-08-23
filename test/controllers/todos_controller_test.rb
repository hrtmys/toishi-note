require "test_helper"

class TodosControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Todo Note", note_type: "todo")
  end

  test "lists only unchecked items" do
    open_item = @note.todo_items.create!(content: "Open")
    @note.todo_items.create!(content: "Done", is_checked: true)

    get todos_url
    assert_response :success
    assert_match open_item.content, response.body
    assert_no_match(/Done/, response.body)
  end

  test "sorts by due date, with items missing a due date last" do
    no_date = @note.todo_items.create!(content: "No date")
    later = @note.todo_items.create!(content: "Later", due_date: 10.days.from_now.to_date)
    sooner = @note.todo_items.create!(content: "Sooner", due_date: 1.day.from_now.to_date)

    get todos_url
    assert_response :success

    positions = [ sooner, later, no_date ].map { |item| response.body.index(item.content) }
    assert_equal positions.sort, positions
  end

  test "never shows another user's todo items" do
    other_note = notes(:two)
    other_item = other_note.todo_items.create!(content: "Not mine")

    get todos_url
    assert_response :success
    assert_no_match(/#{other_item.content}/, response.body)
  end
end
