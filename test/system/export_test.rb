require "application_system_test_case"

class ExportTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Sample Note", content: "# Hi", note_type: "md", notebook: @notebook)
  end

  # The two export-link hrefs are static markup, covered by
  # HomeControllerTest ("the editor export link and the sidebar notebook
  # export icon...") via assert_select — no browser needed. Only the
  # actual download behavior stays here.
  test "clicking Export downloads without navigating away from the editor" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find("#note_editor_header").hover
    click_on I18n.t("home.common.export")

    # A file download shouldn't replace the current page.
    assert_selector "#note_#{@note.id}_title", text: "Sample Note"
  end
end
