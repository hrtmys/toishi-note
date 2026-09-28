require "application_system_test_case"

class ResponsiveLayoutsTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(375, 812)
    @notebook = users(:one).notebooks.create!(name: "Mobile Notebook")
    @folder = @notebook.folders.create!(name: "Mobile Folder")
    @note = @folder.notes.create!(title: "Mobile Note", note_type: "md", notebook: @notebook)
    sign_in_as users(:one)
  end

  test "on a phone-width window the sidebar stays open for notebooks and folders and closes for a note" do
    visit root_url
    find("#sidebarToggleBtn").click
    assert_selector "#sidebarMenu.show"

    phase "1 a notebook keeps the menu open" do
      click_on @notebook.name
      assert_selector "#folders-list", text: @folder.name
      assert_selector "#sidebarMenu.show"
    end

    phase "2 a folder keeps the menu open" do
      click_on @folder.name
      assert_selector "#notes-list", text: @note.title
      assert_selector "#sidebarMenu.show"
    end

    phase "3 a note closes it" do
      within("#notes-list") { click_on @note.title }
      assert_selector "input[value='#{@note.title}']", visible: true
      assert_no_selector "#sidebarMenu.show"
    end
  end
end
