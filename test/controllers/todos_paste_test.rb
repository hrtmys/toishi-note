require "test_helper"

class TodosPasteTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    users(:one).update!(ai_handoff_enabled: true)
    @notebook = users(:one).notebooks.create!(name: "Notebook A")
    @folder = @notebook.folders.create!(name: "Folder A")
    @note = @folder.notes.create!(notebook: @notebook, title: "Groceries", note_type: "todo")
  end

  def digest_from(body)
    match = body.match(/<input[^>]*\bname="digest"[^>]*\bvalue="([^"]*)"/)
    assert match, "expected a hidden digest field in the preview response, got: #{body}"
    match[1]
  end

  def preview_digest(text)
    post "/todos/preview", params: { text: text }, as: :turbo_stream
    assert_response :success
    digest_from(@response.body)
  end

  test "the endpoints 404 when ai_handoff_enabled is off" do
    users(:one).update!(ai_handoff_enabled: false)

    post "/todos/preview", params: { text: "## Groceries\n- [ ] Buy milk" }, as: :turbo_stream
    assert_response :not_found

    post "/todos/apply", params: { text: "## Groceries\n- [ ] Buy milk", digest: "whatever" }, as: :turbo_stream
    assert_response :not_found
  end

  test "applying an add creates exactly one item" do
    text = "## Groceries\n- [ ] Buy milk"
    digest = preview_digest(text)

    assert_difference "TodoItem.count", 1 do
      post "/todos/apply", params: { text: text, digest: digest }, as: :turbo_stream
    end
    assert @note.todo_items.exists?(content: "Buy milk")
  end

  # The single most important test in the PR, at the HTTP boundary.
  test "absence never deletes: pasting one line from a five-item note leaves the other four" do
    kept = Array.new(4) { |i| @note.todo_items.create!(content: "Keep #{i}") }
    pasted = @note.todo_items.create!(content: "Buy milk")
    text = "## Groceries\n- [ ] Buy milk (id: #{pasted.id.to_s(36)})"
    digest = preview_digest(text)

    assert_no_difference "TodoItem.count" do
      post "/todos/apply", params: { text: text, digest: digest }, as: :turbo_stream
    end
    kept.each { |item| assert TodoItem.exists?(item.id) }
  end

  test "(id: <another user's item>;delete!) deletes nothing over HTTP, and the foreign item survives untouched" do
    foreign_item = notes(:two).todo_items.create!(content: "Not yours", is_checked: false)
    original_content = foreign_item.content
    original_updated_at = foreign_item.updated_at
    text = "## Groceries\n- [ ] anything (id: #{foreign_item.id.to_s(36)};delete!)"
    digest = preview_digest(text)

    assert_no_difference "TodoItem.count" do
      post "/todos/apply", params: { text: text, digest: digest }, as: :turbo_stream
    end
    foreign_item.reload
    assert_equal original_content, foreign_item.content
    assert_equal original_updated_at, foreign_item.updated_at
  end

  test "digest guard: mutating the item after preview but before apply aborts with nothing written" do
    item = @note.todo_items.create!(content: "Buy milk")
    text = "## Groceries\n- [x] Buy milk (id: #{item.id.to_s(36)})"
    digest = preview_digest(text)

    item.update!(content: "Buy milk and eggs") # out-of-band change after preview

    assert_no_difference "TodoItem.count" do
      post "/todos/apply", params: { text: text, digest: digest }, as: :turbo_stream
    end
    item.reload
    assert_not item.is_checked
    assert_equal "Buy milk and eggs", item.content
  end

  test "over-cap paste is rejected with nothing applied" do
    body = (1..501).map { |n| "- [ ] task #{n}" }.join("\n")
    text = "## Groceries\n#{body}"

    assert_no_difference "TodoItem.count" do
      post "/todos/apply", params: { text: text, digest: "irrelevant" }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end

  test "the apply is all-or-nothing: one invalid item among a batch rolls back the whole transaction" do
    survivor = @note.todo_items.create!(content: "Existing task")
    doomed_to_survive = @note.todo_items.create!(content: "Delete me")
    text = <<~MD
      ## Groceries
      - [ ] New task
      - [ ] IMPOSSIBLE_CONTENT_SENTINEL
      - [ ] Delete me (id: #{doomed_to_survive.id.to_s(36)};delete!)
    MD
    digest = preview_digest(text)

    # Forces one write in the batch to fail validation, to prove the
    # surrounding transaction rolls back rather than partially committing.
    original_callbacks = TodoItem._validate_callbacks.map(&:filter)
    TodoItem.define_method(:reject_test_sentinel) do
      errors.add(:content, :exclusion) if content == "IMPOSSIBLE_CONTENT_SENTINEL"
    end
    TodoItem.validate :reject_test_sentinel
    begin
      assert_no_difference "TodoItem.count" do
        post "/todos/apply", params: { text: text, digest: digest }, as: :turbo_stream
      end
    ensure
      TodoItem.skip_callback(:validate, :reject_test_sentinel)
      TodoItem.remove_method(:reject_test_sentinel)
    end

    # Removing only what this test added keeps belongs_to's own validation intact.
    assert_equal original_callbacks, TodoItem._validate_callbacks.map(&:filter)

    assert TodoItem.exists?(doomed_to_survive.id)
    assert_not TodoItem.exists?(content: "New task")
    assert TodoItem.exists?(survivor.id)
  end

  [
    [ "empty", "" ],
    [ "whitespace only", "   \n\t  " ],
    [ "a truncated line", "## Groceries\n- [ ] Buy milk (due: 2026-09" ],
    [ "a lone ##", "##" ],
    [ "HTML", "<script>alert(1)</script><div>hi</div>" ],
    [ "the excluded line, English", "## Groceries\n- [ ] Buy milk\n\n1 excluded" ],
    [ "the excluded line, Japanese", "## Groceries\n- [ ] Buy milk\n\n1件を除外中" ],
    [ "arbitrary AI commentary between sections", "## Groceries\nHere's your list, reviewed and organized!\n- [ ] Buy milk\n\n## Chores\n- [ ] Mow lawn" ]
  ].each do |(label, text)|
    test "adversarial input (#{label}) never 500s on preview" do
      post "/todos/preview", params: { text: text }, as: :turbo_stream
      assert_operator @response.status, :<, 500
    end
  end

  test "a 500KB paste never 500s on preview" do
    huge = "## Groceries\n" + ("- [ ] filler task\n" * 30_000)
    assert_operator huge.bytesize, :>, 500_000

    post "/todos/preview", params: { text: huge }, as: :turbo_stream
    assert_operator @response.status, :<, 500
  end

  test "the paste box renders only when ai_handoff_enabled" do
    users(:one).update!(ai_handoff_enabled: false)
    get root_url(todos: true)
    assert_response :success
    assert_select "#todos_paste_form", count: 0

    users(:one).update!(ai_handoff_enabled: true)
    get root_url(todos: true)
    assert_response :success
    assert_select "#todos_paste_form", count: 1
  end

  test "preview lists an add under the adds block" do
    post "/todos/preview", params: { text: "## Groceries\n- [ ] Buy milk\n- [ ] 牛乳を買う" }, as: :turbo_stream

    assert_response :success
    assert_select "#todos_paste_adds li", text: "Buy milk"
    assert_select "#todos_paste_adds li", text: "牛乳を買う"
    assert_select "#todos_paste_deletes", count: 0
  end

  test "preview lists a bound delete with the irreversible warning; another user's id never appears there" do
    own = @note.todo_items.create!(content: "卵を捨てる")
    foreign = notes(:two).todo_items.create!(content: "Foreign secret")

    post "/todos/preview", params: { text: "## Groceries\n- [ ] 卵を捨てる (id: #{own.id.to_s(36)};delete!)" }, as: :turbo_stream
    assert_response :success
    assert_select "#todos_paste_deletes li", text: "卵を捨てる"
    assert_select "#todos_paste_deletes", text: /#{Regexp.escape(I18n.t("home.todos.paste.irreversible"))}/

    post "/todos/preview", params: { text: "## Groceries\n- [ ] Foreign secret (id: #{foreign.id.to_s(36)};delete!)" }, as: :turbo_stream
    assert_response :success
    assert_select "#todos_paste_deletes li", count: 0
    assert TodoItem.exists?(foreign.id)
  end
end
