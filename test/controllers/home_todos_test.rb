require "test_helper"

class HomeTodosTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Todo Note", note_type: "todo")
  end

  test "defaults to the project view" do
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true)

    assert_response :success
    assert_select "a.btn-secondary", text: I18n.t("home.todos.view_project")
  end

  test "an unknown view param falls back to project rather than erroring" do
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true, view: "bogus")

    assert_response :success
    assert_select "a.btn-secondary", text: I18n.t("home.todos.view_project")
  end

  test "the due view keeps due-first ordering with nulls last" do
    no_date = @note.todo_items.create!(content: "No date")
    later = @note.todo_items.create!(content: "Later", due_date: 10.days.from_now.to_date)
    sooner = @note.todo_items.create!(content: "Sooner", due_date: 1.day.from_now.to_date)

    get root_url(todos: true, view: "due")

    assert_response :success
    positions = [ sooner, later, no_date ].map { |item| response.body.index(item.content) }
    assert_equal positions.sort, positions
  end

  test "checked items are excluded from the project view" do
    open_item = @note.todo_items.create!(content: "Open")
    @note.todo_items.create!(content: "Done", is_checked: true)

    get root_url(todos: true, view: "project")

    assert_response :success
    assert_match open_item.content, response.body
    assert_no_match(/Done/, response.body)
  end

  test "checked items are excluded from the due view" do
    open_item = @note.todo_items.create!(content: "Open")
    @note.todo_items.create!(content: "Done", is_checked: true)

    get root_url(todos: true, view: "due")

    assert_response :success
    assert_match open_item.content, response.body
    assert_no_match(/Done/, response.body)
  end

  test "the project view's group header shows notebook, folder and note" do
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true, view: "project")

    assert_response :success
    assert_match "Test Notebook / Test Folder / Todo Note", response.body
  end

  test "a note whose items have no due dates is annotated as a checklist" do
    checklist_note = @folder.notes.create!(notebook: @notebook, title: "Checklist Note", note_type: "todo")
    checklist_note.todo_items.create!(content: "No date at all")
    @note.todo_items.create!(content: "Dated", due_date: 1.day.from_now.to_date)

    get root_url(todos: true, view: "project")

    assert_response :success
    body = response.body
    checklist_index = body.index("Checklist Note")
    dated_index = body.index("Todo Note")

    assert body[checklist_index, 200].include?(I18n.t("home.todos.checklist"))
    assert_not body[dated_index, 200].include?(I18n.t("home.todos.checklist"))
  end

  test "another user's open todo items appear in neither view" do
    other_note = notes(:two)
    other_item = other_note.todo_items.create!(content: "Not mine")

    get root_url(todos: true, view: "project")
    assert_no_match(/#{other_item.content}/, response.body)

    get root_url(todos: true, view: "due")
    assert_no_match(/#{other_item.content}/, response.body)
  end

  test "renders the sidebar rather than a standalone page" do
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true)

    assert_response :success
    assert_select "#sidebarMenu"
  end
end
