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

  test "the ai_excluded column is inert while ai_handoff_enabled is off" do
    excluded = @folder.notes.create!(notebook: @notebook, title: "Excluded Note", note_type: "todo", ai_excluded: true)
    excluded.todo_items.create!(content: "Should still show")

    get root_url(todos: true, view: "project")

    assert_response :success
    assert_match "Should still show", response.body
  end

  test "an excluded note is hidden from the project view once ai_handoff_enabled, with a count line" do
    users(:one).update!(ai_handoff_enabled: true)
    excluded = @folder.notes.create!(notebook: @notebook, title: "Excluded Note", note_type: "todo", ai_excluded: true)
    excluded.todo_items.create!(content: "Should be hidden")
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true, view: "project")

    assert_response :success
    assert_no_match(/Should be hidden/, response.body)
    assert_match "1 excluded", response.body
  end

  test "an excluded note's items are hidden from the due view once ai_handoff_enabled, with a count line" do
    users(:one).update!(ai_handoff_enabled: true)
    excluded = @folder.notes.create!(notebook: @notebook, title: "Excluded Note", note_type: "todo", ai_excluded: true)
    excluded.todo_items.create!(content: "Should be hidden")
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true, view: "due")

    assert_response :success
    assert_no_match(/Should be hidden/, response.body)
    assert_match "1 excluded", response.body
  end

  test "copy buttons are absent from the pane until ai_handoff_enabled" do
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true, view: "project")

    assert_response :success
    assert_no_match(/bi-clipboard/, response.body)
  end

  test "copy buttons appear in the project view once ai_handoff_enabled" do
    users(:one).update!(ai_handoff_enabled: true)
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true, view: "project")

    assert_response :success
    assert_match(/bi-clipboard/, response.body)
  end

  test "todo item content and note titles are HTML-escaped in the project view, not injected raw" do
    malicious_title = "\"><img src=x onerror=alert(1)>"
    note = @folder.notes.create!(notebook: @notebook, title: malicious_title, note_type: "todo")
    note.todo_items.create!(content: "<script>alert(1)</script>")

    get root_url(todos: true, view: "project")

    assert_response :success
    assert_no_match(/<script>alert\(1\)<\/script>/, response.body)
    assert_no_match(/"><img src=x onerror=alert\(1\)>/, response.body)
  end

  test "todo item content is HTML-escaped in the due view, not injected raw" do
    @note.todo_items.create!(content: "<script>alert(1)</script>")

    get root_url(todos: true, view: "due")

    assert_response :success
    assert_no_match(/<script>alert\(1\)<\/script>/, response.body)
  end

  test "renders the sidebar rather than a standalone page" do
    @note.todo_items.create!(content: "Open")

    get root_url(todos: true)

    assert_response :success
    assert_select "#sidebarMenu"
  end
end
