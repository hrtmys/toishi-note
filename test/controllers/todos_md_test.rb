require "test_helper"

class TodosMdTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Notebook A")
    @folder = @notebook.folders.create!(name: "Folder A")
    @note = @folder.notes.create!(notebook: @notebook, title: "Groceries", note_type: "todo")
  end

  test "answers 404 when ai_handoff_enabled is off" do
    @note.todo_items.create!(content: "Buy milk")

    get "/todos.md"

    assert_response :not_found
  end

  test "returns a Structure tree once ai_handoff_enabled is on" do
    users(:one).update!(ai_handoff_enabled: true)
    @note.todo_items.create!(content: "Buy milk")

    get "/todos.md"

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match "## Structure", response.body
    assert_match "Notebook A / Folder A / Groceries (1 open)", response.body
  end

  test "line format includes the base36 id and omits the due suffix when absent" do
    users(:one).update!(ai_handoff_enabled: true)
    item = @note.todo_items.create!(content: "Buy milk")

    get "/todos.md"

    assert_includes response.body, "- [ ] Buy milk (id: #{item.id.to_s(36)})"
  end

  test "line format includes the due date before the id when present, and no empty parens ever appear" do
    users(:one).update!(ai_handoff_enabled: true)
    item = @note.todo_items.create!(content: "Renew passport", due_date: Date.new(2026, 9, 1))
    @note.todo_items.create!(content: "Buy milk")

    get "/todos.md"

    assert_includes response.body, "- [ ] Renew passport (due: 2026-09-01) (id: #{item.id.to_s(36)})"
    assert_no_match(/\(\s*\)/, response.body)
  end

  test "an item checked 3 days ago appears in Recently done, one checked 8 days ago does not" do
    users(:one).update!(ai_handoff_enabled: true)
    recent = @note.todo_items.create!(content: "Recent done")
    stale = @note.todo_items.create!(content: "Stale done")

    travel_to(3.days.ago) { recent.update!(is_checked: true) }
    travel_to(8.days.ago) { stale.update!(is_checked: true) }

    get "/todos.md"

    assert_match "<summary>Recently done (7 days)</summary>", response.body
    assert_includes response.body, "Recent done"
    assert_no_match(/Stale done/, response.body)
  end

  test "an excluded note is absent from the output, and counted in the N excluded line" do
    users(:one).update!(ai_handoff_enabled: true)
    excluded_note = @folder.notes.create!(notebook: @notebook, title: "Shopping", note_type: "todo", ai_excluded: true)
    excluded_note.todo_items.create!(content: "Buy eggs")
    @note.todo_items.create!(content: "Keep this")

    get "/todos.md"

    assert_no_match(/Buy eggs/, response.body)
    assert_match "1 excluded", response.body
  end

  test "no scope param returns the whole account, across notebooks" do
    users(:one).update!(ai_handoff_enabled: true)
    other_notebook = users(:one).notebooks.create!(name: "Notebook B")
    other_folder = other_notebook.folders.create!(name: "Folder B")
    other_note = other_folder.notes.create!(notebook: other_notebook, title: "Other", note_type: "todo")
    other_note.todo_items.create!(content: "Second notebook task")
    @note.todo_items.create!(content: "First notebook task")

    get "/todos.md"

    assert_response :success
    assert_match "First notebook task", response.body
    assert_match "Second notebook task", response.body
  end

  test "note_id wins over folder_id and notebook_id when more than one is given" do
    users(:one).update!(ai_handoff_enabled: true)
    other_note = @folder.notes.create!(notebook: @notebook, title: "Other", note_type: "todo")
    other_note.todo_items.create!(content: "From the other note")
    @note.todo_items.create!(content: "From the target note")

    get "/todos.md", params: { notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id }

    assert_response :success
    assert_match "From the target note", response.body
    assert_no_match(/From the other note/, response.body)
  end

  test "a scope param that resolves to nothing 404s rather than falling back to the whole account" do
    users(:one).update!(ai_handoff_enabled: true)
    @note.todo_items.create!(content: "Should never be returned")

    get "/todos.md", params: { note_id: 0 }

    assert_response :not_found
  end

  test "notebook_id scoped to another user's notebook 404s rather than leaking their tasks" do
    users(:one).update!(ai_handoff_enabled: true)
    notes(:two).todo_items.create!(content: "SECRET_TWO_TASK")

    get "/todos.md", params: { notebook_id: notebooks(:two).id }

    assert_response :not_found
    assert_no_match(/SECRET_TWO_TASK/, response.body.to_s)
  end

  test "folder_id scoped to another user's folder 404s rather than leaking their tasks" do
    users(:one).update!(ai_handoff_enabled: true)
    notes(:two).todo_items.create!(content: "SECRET_TWO_TASK")

    get "/todos.md", params: { folder_id: folders(:two).id }

    assert_response :not_found
    assert_no_match(/SECRET_TWO_TASK/, response.body.to_s)
  end

  test "note_id scoped to another user's note 404s rather than leaking their tasks" do
    users(:one).update!(ai_handoff_enabled: true)
    notes(:two).todo_items.create!(content: "SECRET_TWO_TASK")

    get "/todos.md", params: { note_id: notes(:two).id }

    assert_response :not_found
    assert_no_match(/SECRET_TWO_TASK/, response.body.to_s)
  end

  test "another user's task never leaks into an unscoped request either" do
    users(:one).update!(ai_handoff_enabled: true)
    notes(:two).todo_items.create!(content: "SECRET_TWO_TASK")
    @note.todo_items.create!(content: "Mine")

    get "/todos.md"

    assert_response :success
    assert_no_match(/SECRET_TWO_TASK/, response.body)
  end

  # This is the discriminator for a bare .find replacing Current.user scoping:
  # a bare find would happily resolve someone else's numeric id.
  test "every emitted (id:) decodes, base36, to one of this user's own todo item ids" do
    users(:one).update!(ai_handoff_enabled: true)
    mine = @note.todo_items.create!(content: "Mine")
    theirs = notes(:two).todo_items.create!(content: "Not mine")

    get "/todos.md"

    assert_response :success
    ids = response.body.scan(/\(id: ([0-9a-z]+)\)/).flatten.map { |encoded| encoded.to_i(36) }
    assert_includes ids, mine.id
    assert_not_includes ids, theirs.id
  end

  test "SQL-injection-shaped scope params 404 without error, and never touch the data" do
    users(:one).update!(ai_handoff_enabled: true)

    get "/todos.md", params: { notebook_id: "1 OR 1=1" }
    assert_response :not_found

    get "/todos.md", params: { note_id: "1;DROP TABLE notes--" }
    assert_response :not_found
    assert Note.exists?(@note.id)

    get "/todos.md", params: { folder_id: "' OR '1'='1" }
    assert_response :not_found
  end

  test "a non-numeric scope param 404s instead of raising" do
    users(:one).update!(ai_handoff_enabled: true)

    get "/todos.md", params: { note_id: "abc" }

    assert_response :not_found
  end

  test "a scope param larger than a bigint 404s instead of raising" do
    users(:one).update!(ai_handoff_enabled: true)

    get "/todos.md", params: { note_id: "99999999999999999999" }

    assert_response :not_found
  end

  test "an array where a scalar scope param is expected 404s instead of raising" do
    users(:one).update!(ai_handoff_enabled: true)

    get "/todos.md", params: { "notebook_id[]" => "1" }

    assert_response :not_found
  end

  test "content that looks like a due-date tag but has no real due date passes through verbatim, with the real id last" do
    users(:one).update!(ai_handoff_enabled: true)
    item = @note.todo_items.create!(content: "buy milk (due: 2020-01-01)")

    get "/todos.md"

    assert_includes response.body, "- [ ] buy milk (due: 2020-01-01) (id: #{item.id.to_s(36)})"
  end

  test "content that looks like a fake id tag still ends with the real, resolvable id" do
    users(:one).update!(ai_handoff_enabled: true)
    item = @note.todo_items.create!(content: "refactor (id: zz)")

    get "/todos.md"

    line = response.body.lines.find { |l| l.include?("refactor") }
    assert line, "expected a line containing the item's content"
    assert line.rstrip.end_with?("(id: #{item.id.to_s(36)})"), "expected the real id to be the trailing tag, got: #{line.inspect}"
  end

  test "content containing a newline stays on one line — it must not forge a second entry" do
    users(:one).update!(ai_handoff_enabled: true)
    @note.todo_items.create!(content: "line one\nline two")

    get "/todos.md"

    lines = response.body.lines.map(&:chomp)
    assert_equal 1, lines.count { |l| l.include?("line one") }
    assert_not_includes lines, "line two"
  end

  test "content shaped like a checked checkbox item does not override the real (unchecked) leading state" do
    users(:one).update!(ai_handoff_enabled: true)
    @note.todo_items.create!(content: "- [x] already done", is_checked: false)

    get "/todos.md"

    line = response.body.lines.find { |l| l.include?("already done") }
    assert line, "expected a line containing the item's content"
    assert line.start_with?("- [ ] "), "expected the real unchecked state to lead, got: #{line.inspect}"
    assert_equal 1, response.body.lines.count { |l| l.include?("already done") }
  end

  test "content shaped like a heading does not forge a new group heading" do
    users(:one).update!(ai_handoff_enabled: true)
    @note.todo_items.create!(content: "## Fake Note")

    get "/todos.md"

    assert_not response.body.lines.any? { |l| l.strip == "## Fake Note" }
  end

  test "a note/folder/notebook name containing '##' and a newline does not forge a heading or an extra Structure row" do
    users(:one).update!(ai_handoff_enabled: true)
    hostile_name = "Evil\n## Fake Heading"
    hostile_notebook = users(:one).notebooks.create!(name: hostile_name)
    hostile_folder = hostile_notebook.folders.create!(name: hostile_name)
    hostile_note = hostile_folder.notes.create!(notebook: hostile_notebook, title: hostile_name, note_type: "todo")
    hostile_note.todo_items.create!(content: "Task")

    get "/todos.md"

    assert_response :success
    assert_not response.body.lines.any? { |l| l.strip == "## Fake Heading" }
  end
end
