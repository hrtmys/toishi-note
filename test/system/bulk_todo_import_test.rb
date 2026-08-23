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
end
