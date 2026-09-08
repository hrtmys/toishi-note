require "application_system_test_case"

# Audit finding ux-ui #3: the TODO/Scrap "add" forms had no submitting
# indicator (so a fast double-click could submit twice) and unconditionally
# reset on any Turbo submission outcome, discarding the user's typed input
# on a validation failure or network error instead of leaving it in place.
# Audit finding ux-ui #8: several inputs on the same forms relied on
# placeholder text alone, with no label for assistive tech.
class TodoScrapAddFormTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "the todo add button disables while the request is in flight, then re-enables" do
    note = @folder.notes.create!(title: "Todo Note", note_type: "todo", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    delay_fetch(300)

    fill_in placeholder: I18n.t("home.todo.content_placeholder"), with: "Buy milk"
    click_on I18n.t("home.common.add")

    assert_selector "input[type=submit][disabled]"
    assert_no_selector "input[type=submit][disabled]", wait: 5
  end

  test "a failed todo submission keeps the typed content and shows an error toast" do
    note = @folder.notes.create!(title: "Todo Note", note_type: "todo", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    force_fetch_rejection

    fill_in placeholder: I18n.t("home.todo.content_placeholder"), with: "Buy milk"
    click_on I18n.t("home.common.add")

    assert_selector ".toast.show", text: I18n.t("js.forms.add_failed")
    assert_field placeholder: I18n.t("home.todo.content_placeholder"), with: "Buy milk"
  end

  test "a successful todo submission clears the form" do
    note = @folder.notes.create!(title: "Todo Note", note_type: "todo", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    fill_in placeholder: I18n.t("home.todo.content_placeholder"), with: "Buy milk"
    click_on I18n.t("home.common.add")

    assert_selector "#todo_list_#{note.id}", text: "Buy milk"
    assert_field placeholder: I18n.t("home.todo.content_placeholder"), with: ""
  end

  test "a failed scrap submission keeps the typed content and shows an error toast" do
    note = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    force_fetch_rejection

    fill_in placeholder: I18n.t("home.scrap.content_placeholder"), with: "From a chat"
    click_on I18n.t("home.common.add")

    assert_selector ".toast.show", text: I18n.t("js.forms.add_failed")
    assert_field placeholder: I18n.t("home.scrap.content_placeholder"), with: "From a chat"
  end

  test "a successful scrap submission clears the form" do
    note = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    fill_in placeholder: I18n.t("home.scrap.content_placeholder"), with: "From a chat"
    click_on I18n.t("home.common.add")

    assert_selector "#scrap_list_#{note.id}", text: "From a chat"
    assert_field placeholder: I18n.t("home.scrap.content_placeholder"), with: ""
  end

  test "the todo content field, due-date field, and note title all carry an accessible label" do
    note = @folder.notes.create!(title: "Todo Note", note_type: "todo", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    assert_selector "input[aria-label='#{I18n.t("home.todo.content_placeholder")}']"

    find("button[title='#{I18n.t("home.todo.add_due_date")}']").click
    assert_selector "input[type=date][aria-label='#{I18n.t("home.todo.due_date_label")}']"

    assert_selector "input#note_title_input[aria-label='#{I18n.t("notes.title_placeholder")}']"
  end

  test "the scrap content field carries an accessible label" do
    note = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    assert_selector "textarea[aria-label='#{I18n.t("home.scrap.content_placeholder")}']"
  end

  private

    # Delays every fetch response by the given number of milliseconds,
    # simulating a slow request so the in-flight disabled state is
    # actually observable instead of resolving before Capybara can look.
    def delay_fetch(ms)
      page.execute_script(<<~JS)
        const originalFetch = window.fetch.bind(window)
        window.fetch = (...args) => new Promise((resolve) => {
          window.setTimeout(() => resolve(originalFetch(...args)), #{ms})
        })
      JS
    end

    # Replaces window.fetch with one that always rejects, simulating a
    # network failure (offline, DNS error, CORS, ...) rather than a valid
    # HTTP response.
    def force_fetch_rejection
      page.execute_script(<<~JS)
        window.fetch = () => Promise.reject(new TypeError("Failed to fetch"))
      JS
    end
end
