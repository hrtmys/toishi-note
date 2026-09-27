require "application_system_test_case"

class BulkTodoImportTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Todo Note", note_type: "todo", notebook: @notebook)
  end

  test "pasting a JSON array previews valid and malformed entries, then imports only the valid ones" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    click_on I18n.t("home.todo.bulk_add")
    assert_selector "#bulk_import_modal_#{@note.id}.show"

    fill_in "entries", with: '["Buy milk", {"content": "Call plumber", "checked": true}, 42, "Water the plants"]'

    # The live preview renders before anything is submitted.
    within "#bulk_import_modal_#{@note.id}" do
      assert_selector ".list-group-item", text: "Buy milk"
      assert_selector ".list-group-item", text: "Call plumber"
      assert_selector ".list-group-item", text: "Water the plants"
      assert_selector ".list-group-item-danger", text: "42"
      assert_selector ".list-group-item:not(.list-group-item-danger)", count: 3

      click_on I18n.t("home.common.add")
    end

    assert_no_selector "#bulk_import_modal_#{@note.id}.show"

    within "#todo_list_#{@note.id}" do
      assert_text "Buy milk"
      assert_text "Call plumber"
      assert_text "Water the plants"
      assert_no_text "42"
    end

    assert_equal [ "Buy milk", "Call plumber", "Water the plants" ], @note.todo_items.order(:position).pluck(:content)
    assert @note.todo_items.find_by!(content: "Call plumber").is_checked
  end

  test "invalid JSON shows an error and keeps the Add button disabled" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    click_on I18n.t("home.todo.bulk_add")
    assert_selector "#bulk_import_modal_#{@note.id}.show"

    fill_in "entries", with: "this is not json"

    within "#bulk_import_modal_#{@note.id}" do
      assert_text I18n.t("js.bulk_import.invalid_json")
      assert_button I18n.t("home.common.add"), disabled: true
    end
  end
  test "pasting Markdown checklist lines previews them, groups by ## heading, and imports them" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    click_on I18n.t("home.todo.bulk_add")
    assert_selector "#bulk_import_modal_#{@note.id}.show"

    fill_in "entries", with: <<~MD
      ## Groceries
      - [ ] Buy milk (due: 2026-09-30)
      - [x] Call plumber
      ## Chores
      - [ ] Water the plants
    MD

    within "#bulk_import_modal_#{@note.id}" do
      assert_selector ".list-group-item", text: "Buy milk"
      assert_selector ".list-group-item", text: "Call plumber"
      assert_selector ".list-group-item", text: "Water the plants"
      assert_selector ".list-group-item", text: "Groceries"
      assert_selector ".list-group-item", text: "Chores"

      click_on I18n.t("home.common.add")
    end

    assert_no_selector "#bulk_import_modal_#{@note.id}.show"

    contents = @note.todo_items.reload.order(:position).map(&:content)
    assert_includes contents, "Buy milk"
    assert_includes contents, "Water the plants"
    assert_equal Date.new(2026, 9, 30), @note.todo_items.find_by(content: "Buy milk").due_date
    assert @note.todo_items.find_by(content: "Call plumber").is_checked
  end

  # The modal appends to one note and cannot delete, so a line asking for a
  # deletion is refused rather than silently imported without its marker.
  test "a Markdown line carrying a removal marker is shown as invalid and blocks submission" do
    item = @note.todo_items.create!(content: "Existing")
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    click_on I18n.t("home.todo.bulk_add")
    assert_selector "#bulk_import_modal_#{@note.id}.show"

    fill_in "entries", with: "- [ ] Existing (id: #{item.id.to_s(36)};delete!)"

    within "#bulk_import_modal_#{@note.id}" do
      assert_selector ".list-group-item-danger"
      assert_button I18n.t("home.common.add"), disabled: true
    end

    assert TodoItem.exists?(item.id)
  end
end
