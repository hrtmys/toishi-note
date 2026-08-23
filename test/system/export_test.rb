require "application_system_test_case"

class ExportTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Sample Note", content: "# Hi", note_type: "md", notebook: @notebook)
  end

  test "the note editor's Export link points at the note's export endpoint" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    export_link = find_link(I18n.t("home.common.export"), visible: :all)
    assert_equal export_note_url(@note), export_link[:href]
  end

  test "the notebook row's export icon points at the notebook's export endpoint" do
    visit root_url(notebook_id: @notebook.id)

    notebook_row = find("#notebooks-list li", text: @notebook.name)
    export_link = notebook_row.find("a[title='#{I18n.t("home.notebooks.export")}']", visible: :all)
    assert_equal export_notebook_url(@notebook), export_link[:href]
  end

  test "clicking Export downloads without navigating away from the editor" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find("#note_editor_header").hover
    click_on I18n.t("home.common.export")

    # A file download shouldn't replace the current page.
    assert_selector "#note_#{@note.id}_title", text: "Sample Note"
  end
end
