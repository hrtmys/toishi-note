require "application_system_test_case"

class NoteSortTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")

    # Oldest first, so "Updated"/"Created" desc (the default) and "A-Z"
    # asc land in different, distinguishable orders.
    @banana = @folder.notes.create!(notebook: @notebook, title: "Banana", note_type: "md", created_at: 3.days.ago, updated_at: 3.days.ago)
    @apple = @folder.notes.create!(notebook: @notebook, title: "Apple", note_type: "md", created_at: 2.days.ago, updated_at: 2.days.ago)
    @cherry = @folder.notes.create!(notebook: @notebook, title: "Cherry", note_type: "md", created_at: 1.day.ago, updated_at: 1.day.ago)
  end

  test "clicking A-Z sorts alphabetically, and clicking it again flips the direction" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id)

    # Default: newest-updated-first.
    assert_equal [ "Cherry", "Apple", "Banana" ], note_titles

    click_on "A-Z"
    assert_equal [ "Apple", "Banana", "Cherry" ], note_titles

    click_on "A-Z"
    assert_equal [ "Cherry", "Banana", "Apple" ], note_titles
  end

  test "pinning a note keeps it at the top regardless of sort mode, and persists across a reload" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id)

    banana_row = find("#notes-list li", text: "Banana")
    banana_row.hover
    banana_row.find(".hover-target-icon[title='#{I18n.t("home.notes.pin")}']").click

    assert_equal [ "Banana", "Cherry", "Apple" ], note_titles

    click_on "A-Z"
    assert_equal [ "Banana", "Apple", "Cherry" ], note_titles

    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.1 until @banana.reload.is_pinned?
    end

    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id)
    assert_equal [ "Banana", "Cherry", "Apple" ], note_titles
  end

  private

  def note_titles
    all("#notes-list li span[id^='note_']").map(&:text)
  end
end
