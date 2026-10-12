require "test_helper"

# An unchanged todos.md export, pasted back, must plan no operations (#95).
class TodoHandoffRoundtripTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(ai_handoff_enabled: true)
    notebook = @user.notebooks.create!(name: "買い物")
    folder = notebook.folders.create!(name: "自宅")
    @note = folder.notes.create!(notebook: notebook, title: "週末", note_type: "todo")
  end

  test "an unchanged todos.md round trip plans no operations for items with due dates" do
    @note.todo_items.create!(content: "牛乳を買う")
    @note.todo_items.create!(content: "パスポートを更新（期限あり）", due_date: Date.new(2026, 9, 1))
    @note.todo_items.create!(content: "請求書を送る (経理)", due_date: Date.new(2026, 10, 12))
    @note.todo_items.create!(content: "Renew passport", due_date: Date.new(2026, 10, 1))

    exported = TodoHandoff.new(user: @user).to_markdown
    plan = TodoApplyPlan.new(TodoPaste.parse(exported).lines, user: @user)

    assert_empty plan.operations
    assert_empty plan.skipped
  end
end
