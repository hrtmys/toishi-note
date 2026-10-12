require "application_system_test_case"

class TodoNoteTest < ApplicationSystemTestCase
  CONTENT = "input[placeholder='#{I18n.t("home.todo.content_placeholder")}']".freeze
  XSS = "<img src=x onerror=window.__xss_fired=true>".freeze

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    @user = users(:one)
    @user.update!(ai_handoff_enabled: true)
    @notebook = @user.notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Todo Note", note_type: "todo", notebook: @notebook)
    sign_in_as @user
  end

  test "the TODO note's add form, bulk import and AI copy work end to end" do
    due = Date.current.next_year

    phase "1 add with a due date, disabled while in flight" do
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
      record_toasts
      assert_no_selector "input[name='due_date']", visible: true
      find(CONTENT).fill_in(with: "パスポート更新")
      find("button[title='#{I18n.t("home.todo.add_due_date")}']").click
      assert_selector "input[name='due_date']", visible: true
      fill_in "due_date", with: due.strftime("%m/%d/%Y")
      delay_fetch(300)
      click_on I18n.t("home.common.add")
      assert_selector "input[type=submit][disabled][value='#{I18n.t("js.forms.adding")}']"
      assert_no_selector "input[type=submit][disabled]"
      within "#todo_list_#{@note.id}" do
        assert_text "パスポート更新"
        assert_selector ".badge", text: due.strftime("%-m/%-d")
      end
      assert_equal "", find(CONTENT).value
    end

    phase "2 a failed add keeps the typed text and toasts" do
      force_fetch_rejection
      find(CONTENT).fill_in(with: "Buy milk")
      click_on I18n.t("home.common.add")
      assert_selector ".toast.show", text: I18n.t("js.forms.add_failed")
      assert_equal "Buy milk", find(CONTENT).value
      assert_no_toast I18n.t("js.forms.save_failed")

      passport = @note.todo_items.find_by!(content: "パスポート更新")
      find("#todo_item_#{passport.id} input[type='checkbox']").click
      assert_toast I18n.t("js.forms.save_failed")
      assert_no_selector "#todo_item_#{passport.id} input[type='checkbox']:checked"
      assert_not passport.reload.is_checked?
      restore_fetch
      find(CONTENT).fill_in(with: "")
    end

    phase "3 bulk import: invalid JSON blocks, valid JSON previews inertly and imports" do
      modal = "#bulk_import_modal_#{@note.id}"
      click_on I18n.t("home.todo.bulk_add")
      assert_selector "#{modal}.show"
      fill_in "entries", with: "this is not json"
      within modal do
        assert_text I18n.t("js.bulk_import.invalid_json")
        assert_button I18n.t("home.common.add"), disabled: true
      end

      fill_in "entries", with: [ "Buy milk", { content: "Call plumber", checked: true }, 42, XSS ].to_json
      within modal do
        assert_selector ".list-group-item:not(.list-group-item-danger)", count: 3
        assert_selector ".list-group-item-danger", count: 1
        assert_selector ".list-group-item", text: XSS
        assert_no_selector "img"
        click_on I18n.t("home.common.add")
      end
      assert_no_selector "#{modal}.show"
      assert_nil evaluate_script("window.__xss_fired")
      wait_until("the bulk import never landed") { @note.todo_items.count == 4 }
      assert_equal [ "パスポート更新", "Buy milk", "Call plumber", XSS ], @note.todo_items.order(:position).pluck(:content)
      assert @note.todo_items.find_by!(content: "Call plumber").is_checked?
    end

    phase "3b add, then tick two items in the same JS tick" do
      milk = @note.todo_items.find_by!(content: "Buy milk")
      xss = @note.todo_items.find_by!(content: XSS)
      find(CONTENT).fill_in(with: "Renew visa")
      execute_script(<<~JS, note_todo_items_path(@note), milk.id, xss.id)
        document.querySelector(`form[action="${arguments[0]}"]`).requestSubmit()
        document.querySelector(`#todo_item_${arguments[1]} input[type="checkbox"]`).click()
        document.querySelector(`#todo_item_${arguments[2]} input[type="checkbox"]`).click()
      JS

      within("#todo_list_#{@note.id}") { assert_text "Renew visa" }
      assert_equal "", find(CONTENT).value
      assert_selector "#todo_item_#{milk.id} .text-decoration-line-through"
      assert_selector "#todo_item_#{xss.id} .text-decoration-line-through"
      within("#todo_progress_#{@note.id}") { assert_text "3 / 5" }
      wait_until("the add and both ticks never all saved") do
        @note.todo_items.count == 5 && milk.reload.is_checked? && xss.reload.is_checked?
      end
      assert_equal 1, @note.todo_items.where(content: "Renew visa").count
      assert_no_toast I18n.t("js.forms.add_failed")
      assert_no_toast I18n.t("js.forms.save_failed")
    end

    item = @note.todo_items.find_by!(content: "パスポート更新")
    visa = @note.todo_items.find_by!(content: "Renew visa")

    phase "4 AI handoff copy carries the item and its id" do
      visit root_url(todos: true)
      record_toasts
      execute_script(<<~JS)
        window.__copiedText = null
        navigator.clipboard.writeText = (text) => { window.__copiedText = text; return Promise.resolve() }
      JS
      find("button.ai-handoff-gated", match: :first).click
      assert_toast I18n.t("js.copied")
      copied = evaluate_script("window.__copiedText")
      assert_includes copied, "パスポート更新"
      assert_match(/\(id: [0-9a-z]+\)/, copied)
    end

    phase "5 checking two items off in the project view in one tick removes both" do
      assert_selector "#all_todos_item_#{visa.id}"
      execute_script(<<~JS, item.id, visa.id)
        document.querySelector(`#all_todos_item_${arguments[0]} input[type="checkbox"]`).click()
        document.querySelector(`#all_todos_item_${arguments[1]} input[type="checkbox"]`).click()
      JS
      assert_no_selector "#all_todos_item_#{item.id}"
      assert_no_selector "#all_todos_item_#{visa.id}"
      wait_until("the check-offs never saved") { item.reload.is_checked? && visa.reload.is_checked? }
      assert_no_toast I18n.t("js.forms.save_failed")
    end
  end
end
