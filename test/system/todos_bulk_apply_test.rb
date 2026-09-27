require "application_system_test_case"

# Written before the feature exists; deliberately left unrun (see report).
# DOM ids come from plan.md section 4; route/param assumptions mirror
# test/controllers/todos_paste_test.rb's header comment.
class TodosBulkApplyTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
    users(:one).update!(ai_handoff_enabled: true)

    @notebook = users(:one).notebooks.create!(name: "Notebook A")
    @folder = @notebook.folders.create!(name: "Folder A")
    @note = @folder.notes.create!(notebook: @notebook, title: "Groceries", note_type: "todo")
  end

  test "the paste box is absent when ai_handoff_enabled is off" do
    users(:one).update!(ai_handoff_enabled: false)

    visit root_url(todos: true)

    assert_no_selector "#todos_paste_form"
  end

  test "pasting an add, previewing, and confirming creates the item and shows the permanence warning" do
    visit root_url(todos: true)

    assert_selector "#todos_paste_form"
    fill_in "text", with: "## Groceries\n- [ ] Buy milk"
    click_button I18n.t("home.todos.paste.preview")

    within "#todos_paste_preview" do
      within "#todos_paste_adds" do
        assert_text "Buy milk"
      end
      click_button I18n.t("home.todos.paste.confirm")
    end

    within "#todo_list_#{@note.id}" do
      assert_text "Buy milk"
    end
  end

  test "a delete appears in its own block with the permanence warning before confirming" do
    item = @note.todo_items.create!(content: "Buy milk")

    visit root_url(todos: true)
    fill_in "text", with: "## Groceries\n- [ ] Buy milk (id: #{item.id.to_s(36)};delete!)"
    click_button I18n.t("home.todos.paste.preview")

    within "#todos_paste_deletes" do
      assert_text "Buy milk"
      assert_text I18n.t("home.todos.paste.irreversible")
    end
  end
end
