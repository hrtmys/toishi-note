require "test_helper"

# TodoApplyPlan resolves parsed lines into operations without writing.
# Public contract assumed here (class doesn't exist yet — see report):
# .new(lines, user:).operations/.skipped, ops carry #type/#note/#item/etc.
class TodoApplyPlanTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @notebook = @user.notebooks.create!(name: "Notebook")
    @folder = @notebook.folders.create!(name: "Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Groceries", note_type: "todo")
  end

  def plan_for(text, user: @user)
    TodoApplyPlan.new(TodoPaste.parse(text).lines, user: user)
  end

  test "an unbound line becomes an add to the note matched by heading" do
    plan = plan_for("## Groceries\n- [ ] Buy milk")

    adds = plan.operations.select { |op| op.type == :add }
    assert_equal 1, adds.size
    assert_equal @note, adds.first.note
    assert_equal "Buy milk", adds.first.content
  end

  test "a heading matching two notes skips the whole group and reports it" do
    @folder.notes.create!(notebook: @notebook, title: "Groceries", note_type: "todo")

    plan = plan_for("## Groceries\n- [ ] Buy milk")

    assert_empty plan.operations
    assert_equal 1, plan.skipped.size
    assert_equal "Groceries", plan.skipped.first.heading
  end

  test "a heading matching no note warns and skips" do
    plan = plan_for("## No Such Note\n- [ ] Buy milk")

    assert_empty plan.operations
    assert_equal 1, plan.skipped.size
  end

  test "a malformed id does not bind: the line becomes an add whose content keeps the tag" do
    plan = plan_for("## Groceries\n- [ ] Buy milk (id: !!!not-an-id)")

    adds = plan.operations.select { |op| op.type == :add }
    assert_equal 1, adds.size
    assert_includes adds.first.content, "(id: !!!not-an-id)"
  end

  test "an unknown (but well-formed) id does not bind and becomes an add" do
    plan = plan_for("## Groceries\n- [ ] Buy milk (id: zzzzzz)")

    assert_equal 1, plan.operations.count { |op| op.type == :add }
    assert_empty plan.operations.select { |op| op.type == :delete }
  end

  # The single most important test in the grammar: a foreign id must never
  # bind, must never be touched, and the failure mode if Current.user
  # scoping is dropped is an actual cross-account delete.
  test "(id: <another user's item>;delete!) deletes nothing and leaves the foreign item untouched" do
    other_note = notes(:two)
    # A real due date, not nil, so the due assertion below actually asserts something.
    foreign_item = other_note.todo_items.create!(content: "Not yours", is_checked: false, due_date: Date.new(2026, 1, 1))
    original_content = foreign_item.content
    original_checked = foreign_item.is_checked
    original_due = foreign_item.due_date
    original_updated_at = foreign_item.updated_at

    plan = plan_for("## Groceries\n- [ ] anything (id: #{foreign_item.id.to_s(36)};delete!)")

    assert_empty plan.operations.select { |op| op.type == :delete }
    foreign_item.reload
    assert_equal original_content, foreign_item.content
    assert_equal original_checked, foreign_item.is_checked
    assert_equal original_due, foreign_item.due_date
    assert_equal original_updated_at, foreign_item.updated_at
  end

  test "another user's plain (unmarked) id also does not bind, and becomes a harmless add" do
    other_note = notes(:two)
    foreign_item = other_note.todo_items.create!(content: "Not yours")

    plan = plan_for("## Groceries\n- [ ] anything (id: #{foreign_item.id.to_s(36)})")

    assert_empty plan.operations.select { |op| op.type == :delete }
    assert_equal 1, plan.operations.count { |op| op.type == :add }
  end

  test ";delete! on the current user's own bound item deletes exactly that item" do
    item = @note.todo_items.create!(content: "Buy milk")
    other_item = @note.todo_items.create!(content: "Buy eggs")

    plan = plan_for("## Groceries\n- [ ] Buy milk (id: #{item.id.to_s(36)};delete!)")

    deletes = plan.operations.select { |op| op.type == :delete }
    assert_equal 1, deletes.size
    assert_equal item, deletes.first.item
    assert_not_equal other_item, deletes.first.item
  end

  test "content change on a bound id produces a delete and an add, both present" do
    item = @note.todo_items.create!(content: "Buy milk")

    plan = plan_for("## Groceries\n- [ ] Buy milk and eggs (id: #{item.id.to_s(36)})")

    assert_equal 1, plan.operations.count { |op| op.type == :delete && op.item == item }
    assert_equal 1, plan.operations.count { |op| op.type == :add && op.content == "Buy milk and eggs" }
  end

  test "checkbox differing on otherwise-matching bound content produces a check operation, both directions" do
    unchecked = @note.todo_items.create!(content: "Buy milk", is_checked: false)
    checked = @note.todo_items.create!(content: "Buy eggs", is_checked: true)

    plan = plan_for(<<~MD)
      ## Groceries
      - [x] Buy milk (id: #{unchecked.id.to_s(36)})
      - [ ] Buy eggs (id: #{checked.id.to_s(36)})
    MD

    check_ops = plan.operations.select { |op| op.type == :check }
    assert_equal 2, check_ops.size
    assert check_ops.find { |op| op.item == unchecked }.checked
    assert_not check_ops.find { |op| op.item == checked }.checked
  end

  test "a due change on matching content is reported old -> new" do
    item = @note.todo_items.create!(content: "Renew passport", due_date: Date.new(2026, 1, 1))

    plan = plan_for("## Groceries\n- [ ] Renew passport (due: 2026-09-01) (id: #{item.id.to_s(36)})")

    due_ops = plan.operations.select { |op| op.type == :due_change }
    assert_equal 1, due_ops.size
    assert_equal Date.new(2026, 1, 1), due_ops.first.old_due
    assert_equal Date.new(2026, 9, 1), due_ops.first.new_due
  end

  test "(due: none) clears an existing due date" do
    item = @note.todo_items.create!(content: "Renew passport", due_date: Date.new(2026, 1, 1))

    plan = plan_for("## Groceries\n- [ ] Renew passport (due: none) (id: #{item.id.to_s(36)})")

    due_ops = plan.operations.select { |op| op.type == :due_change }
    assert_equal 1, due_ops.size
    assert_nil due_ops.first.new_due
  end

  # Absence never deletes: the single most important test in the whole PR.
  test "a note with five items pasted back with only one line leaves the other four untouched" do
    kept = Array.new(4) { |i| @note.todo_items.create!(content: "Keep #{i}") }
    pasted = @note.todo_items.create!(content: "Buy milk")

    plan = plan_for("## Groceries\n- [ ] Buy milk (id: #{pasted.id.to_s(36)})")

    assert_empty plan.operations.select { |op| op.type == :delete }
    kept.each { |item| assert TodoItem.exists?(item.id) }
  end

  test "a missing due tag on a bound, content-matching item does not clear its due date" do
    item = @note.todo_items.create!(content: "Renew passport", due_date: Date.new(2026, 1, 1))

    plan = plan_for("## Groceries\n- [ ] Renew passport (id: #{item.id.to_s(36)})")

    assert_empty plan.operations.select { |op| op.type == :due_change }
  end

  test "exact-duplicate lines are skipped after the first" do
    item = @note.todo_items.create!(content: "Buy milk")
    plan = plan_for(<<~MD)
      ## Groceries
      - [ ] Buy milk (id: #{item.id.to_s(36)};delete!)
      - [ ] Buy milk (id: #{item.id.to_s(36)};delete!)
    MD

    assert_equal 1, plan.operations.count { |op| op.type == :delete }
    assert_equal 1, plan.skipped.size
  end

  test "a removal marker on an unbound line is skipped, not treated as an add" do
    plan = plan_for("## Groceries\n- [ ] anything (id: zzzzzz;delete!)")

    assert_empty plan.operations
    assert_equal 1, plan.skipped.size
  end

  test "a bound line carrying both ;delete! and changed content is skipped, item and text survive" do
    item = @note.todo_items.create!(content: "Buy milk")

    plan = plan_for("## Groceries\n- [ ] Buy milk and eggs (id: #{item.id.to_s(36)};delete!)")

    assert_empty plan.operations
    assert_equal 1, plan.skipped.size
    item.reload
    assert_equal "Buy milk", item.content
    assert TodoItem.exists?(item.id)
  end

  test "content that becomes empty once tags are stripped produces no add" do
    plan = plan_for("## Groceries\n- [ ] (id: zzzzzz)")

    assert_empty plan.operations
  end
  # Two lines naming the same item with different intents leave the outcome
  # decided by line order alone, so neither is applied.
  test "two lines binding the same id with conflicting intents are both skipped" do
    item = @note.todo_items.create!(content: "Buy milk")
    text = <<~MD
      ## #{@note.title}
      - [ ] Buy milk and eggs (id: #{item.id.to_s(36)})
      - [ ] Buy milk (id: #{item.id.to_s(36)};delete!)
    MD

    plan = plan_for(text)

    assert_empty plan.operations.select { |op| op.item&.id == item.id }
    assert_includes plan.skipped.map(&:reason), :conflicting_lines
  end

  test "the same id appearing on two identical lines is a duplicate, not a conflict" do
    item = @note.todo_items.create!(content: "Buy milk", due_date: Date.new(2026, 9, 30))
    line = "- [ ] Buy milk (due: 2026-10-01) (id: #{item.id.to_s(36)})"

    plan = plan_for("## #{@note.title}\n#{line}\n#{line}")

    assert_equal 1, plan.operations.count { |op| op.type == :due_change }
    assert_not_includes plan.skipped.map(&:reason), :conflicting_lines
  end
end
