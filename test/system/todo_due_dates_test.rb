require "application_system_test_case"

class TodoDueDatesTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Todo Note", note_type: "todo", notebook: @notebook)
  end

  test "adding a task with a due date shows it on the item, and it appears in the All open TODOs view" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    # The due-date field starts collapsed — no sense of obligation.
    assert_no_selector "input[name='due_date']", visible: true

    fill_in "content", with: "Renew passport"
    find("button[title='#{I18n.t("home.todo.add_due_date")}']").click
    assert_selector "input[name='due_date']", visible: true

    fill_in "due_date", with: Date.current.next_year.strftime("%m/%d/%Y")
    click_on I18n.t("home.common.add")

    within "#todo_list_#{@note.id}" do
      assert_text "Renew passport"
      assert_selector ".badge", text: Date.current.next_year.strftime("%-m/%-d")
    end

    visit todos_path
    assert_text "Renew passport"
    assert_text "Test Notebook / Test Folder / Todo Note"
  end

  test "an overdue task is badged red, and checking it off in the All open TODOs view removes it from the list" do
    item = @note.todo_items.create!(content: "Overdue task", due_date: 2.days.ago.to_date)

    visit todos_path
    click_on I18n.t("home.todos.view_due")
    within "#all_todos_item_#{item.id}" do
      assert_selector ".badge.text-bg-danger"
      find("input[type='checkbox']").check
    end

    assert_no_selector "#all_todos_item_#{item.id}"
    assert item.reload.is_checked?
  end

  test "opening the Todos pane from the sidebar, toggling views, checking an item off, and going back" do
    item = @note.todo_items.create!(content: "Pack bags", due_date: 1.day.from_now.to_date)

    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    find("a[title='#{I18n.t('home.header.all_open_todos')}']").click

    assert_text "Test Notebook / Test Folder / Todo Note"

    click_on I18n.t("home.todos.view_due")
    assert_text "Pack bags"
    click_on I18n.t("home.todos.view_project")
    assert_text "Pack bags"

    within "#all_todos_item_#{item.id}" do
      find("input[type='checkbox']").check
    end
    assert_no_selector "#all_todos_item_#{item.id}"

    find("a[title='#{I18n.t('home.todos.back')}']").click

    assert_selector "input[value='#{@note.title}']"
  end
end
