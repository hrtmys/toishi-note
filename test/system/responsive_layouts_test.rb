require "application_system_test_case"

class ResponsiveLayoutsTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(375, 812)
    sign_in_as users(:one)
  end

  test "accessing note content from note list on mobile view" do
    visit root_url

    # Grab the note under test.
    note = users(:one).notes.first

    # Click the button that opens the menu (the header's hamburger button).
    find("#sidebarToggleBtn").click

    # Give the off-canvas animation a moment to finish opening.
    assert_selector "#sidebarMenu.show"

    # Click the note's link.
    first("a", text: note.title).click

    # Important: don't just check the area exists — verify the clicked note's
    # title actually made it into the right column's input field (see
    # notes/_title_input.html.erb, this checks that input element's value).
    assert_selector "input[value='#{note.title}']", visible: true

    # After navigating, verify the sidebar is hidden again.
    assert_no_selector "#sidebarMenu.show"
  end

  test "selecting a notebook keeps the menu open, unlike selecting a file" do
    notebook = users(:one).notebooks.create!(name: "Mobile Notebook")

    visit root_url
    find("#sidebarToggleBtn").click
    assert_selector "#sidebarMenu.show"

    # Picking a notebook is a step toward picking a folder/file, not a
    # terminal action — the click must not close the menu. Checked via
    # the "show" class rather than chaining a second click.
    click_on notebook.name
    assert_selector "#sidebarMenu.show"
  end

  test "selecting a folder keeps the menu open, unlike selecting a file" do
    notebook = users(:one).notebooks.create!(name: "Mobile Notebook")
    folder = notebook.folders.create!(name: "Mobile Folder")

    visit root_url(notebook_id: notebook.id)
    find("#sidebarToggleBtn").click
    assert_selector "#sidebarMenu.show"

    click_on folder.name
    assert_selector "#sidebarMenu.show"
  end
end
