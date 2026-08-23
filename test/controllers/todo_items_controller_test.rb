require "test_helper"

class TodoItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Todo Note", note_type: "todo")
    @item = @note.todo_items.create!(content: "Existing task")
  end

  test "should create todo item" do
    assert_difference("TodoItem.count") do
      post note_todo_items_url(@note), params: { content: "Buy milk" }, as: :turbo_stream
    end
    assert_response :success
  end

  test "should not create todo item with blank content" do
    assert_no_difference("TodoItem.count") do
      post note_todo_items_url(@note), params: { content: "   " }, as: :turbo_stream
    end
    assert_response :success
  end

  test "should update todo item checked state" do
    patch note_todo_item_url(@note, @item), params: { is_checked: true }, as: :turbo_stream
    assert_response :success
    @item.reload
    assert_equal true, @item.is_checked
  end

  test "create accepts an optional due date" do
    post note_todo_items_url(@note), params: { content: "Renew passport", due_date: "2026-09-01" }, as: :turbo_stream
    assert_equal Date.new(2026, 9, 1), @note.todo_items.find_by!(content: "Renew passport").due_date
  end

  test "create leaves due_date blank when none is given" do
    post note_todo_items_url(@note), params: { content: "No deadline" }, as: :turbo_stream
    assert_nil @note.todo_items.find_by!(content: "No deadline").due_date
  end

  test "checking an item off also removes it from the all-open-TODOs view" do
    patch note_todo_item_url(@note, @item), params: { is_checked: true }, as: :turbo_stream
    assert_match(/all_todos_item_#{@item.id}/, @response.body)
  end

  test "unchecking an item does not try to remove anything from the all-open-TODOs view" do
    @item.update!(is_checked: true)
    patch note_todo_item_url(@note, @item), params: { is_checked: false }, as: :turbo_stream
    assert_no_match(/all_todos_item_#{@item.id}/, @response.body)
  end

  test "should destroy todo item" do
    assert_difference("TodoItem.count", -1) do
      delete note_todo_item_url(@note, @item), as: :turbo_stream
    end
    assert_response :success
  end

  test "bulk_create imports every task from a JSON array of plain strings" do
    assert_difference("TodoItem.count", 2) do
      post bulk_create_note_todo_items_url(@note), params: { entries: '["Buy milk", "Call plumber"]' }, as: :turbo_stream
    end
    assert_response :success
    assert_equal [ "Buy milk", "Call plumber" ], @note.todo_items.order(:position).last(2).map(&:content)
  end

  test "bulk_create honors a checked flag on object entries" do
    post bulk_create_note_todo_items_url(@note), params: {
      entries: '[{"content": "Already done", "checked": true}, {"content": "Not yet"}]'
    }, as: :turbo_stream

    assert @note.todo_items.find_by!(content: "Already done").is_checked
    assert_not @note.todo_items.find_by!(content: "Not yet").is_checked
  end

  test "bulk_create appends after the existing items instead of resetting position" do
    post bulk_create_note_todo_items_url(@note), params: { entries: '["New task"]' }, as: :turbo_stream

    new_item = @note.todo_items.find_by!(content: "New task")
    assert_operator new_item.position, :>, @item.position
  end

  test "bulk_create skips malformed entries but still imports the valid ones alongside them" do
    assert_difference("TodoItem.count", 2) do
      post bulk_create_note_todo_items_url(@note), params: {
        entries: '["Valid one", null, 42, {"no_content": true}, "", "  ", "Valid two"]'
      }, as: :turbo_stream
    end
    assert_response :success
    assert_equal [ "Valid one", "Valid two" ], @note.todo_items.order(:position).last(2).map(&:content)
  end

  test "bulk_create imports nothing from invalid JSON, without raising" do
    assert_no_difference("TodoItem.count") do
      post bulk_create_note_todo_items_url(@note), params: { entries: "not json at all" }, as: :turbo_stream
    end
    assert_response :success
  end

  test "bulk_create imports nothing when the JSON isn't an array" do
    assert_no_difference("TodoItem.count") do
      post bulk_create_note_todo_items_url(@note), params: { entries: '{"content": "Not an array"}' }, as: :turbo_stream
    end
    assert_response :success
  end

  test "bulk_create only ever targets the current user's note" do
    other_note = notes(:two) # belongs to users(:two), not the signed-in users(:one)

    post bulk_create_note_todo_items_url(other_note), params: { entries: '["Sneaky"]' }, as: :turbo_stream

    assert_response :not_found
    assert_not other_note.todo_items.exists?(content: "Sneaky")
  end
end
