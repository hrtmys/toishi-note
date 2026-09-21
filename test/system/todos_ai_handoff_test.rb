require "application_system_test_case"

class TodosAiHandoffTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Todo Note", note_type: "todo")
    @note.todo_items.create!(content: "Buy milk")
  end

  test "the copy button is hidden until ai_handoff_enabled, appears without a reload, copies, and persists" do
    visit root_url(todos: true)

    assert_no_selector "i.bi-clipboard"

    find("button[title='Settings']").click
    assert_selector "#settingsModal.show"

    within "#settingsModal" do
      check "aiHandoffToggle"
    end

    # No reload happened — Turbo/Capybara would otherwise reset the page.
    assert_selector "button:has(i.bi-clipboard)"

    wait_until("ai_handoff_enabled PATCH never landed") { users(:one).reload.ai_handoff_enabled? }

    find("button:has(i.bi-clipboard)", match: :first).click
    assert_selector ".toast.show", text: I18n.t("js.copied")

    visit root_url(todos: true)
    assert_selector "button:has(i.bi-clipboard)"
  end
end
