require "application_system_test_case"

class NavigationRestoreTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
  end

  test "a bare root visit restores the last note you had open" do
    notebook = users(:one).notebooks.create!(name: "Nav Notebook")
    folder = notebook.folders.create!(name: "Nav Folder")
    note = folder.notes.create!(title: "Nav Note", note_type: "md", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)
    # Click the note's own sidebar link so storeLocation records this URL.
    within "#notes-list" do
      click_on note.title
    end

    visit root_url

    assert_selector "input[value='#{note.title}']"
  end

  test "creating a new note lands on it, even with a stale lastPath from an earlier note" do
    notebook = users(:one).notebooks.create!(name: "Nav Notebook")
    folder = notebook.folders.create!(name: "Nav Folder")
    old_note = folder.notes.create!(title: "Old Note", note_type: "md", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: old_note.id)
    within "#notes-list" do
      click_on old_note.title
    end

    # Every note editor page is "/" with query-string state — creating a
    # note (a redirect, so storeLocation never runs) must not get yanked
    # back to this stale lastPath just because the pathname matches.
    visit root_url(notebook_id: notebook.id, folder_id: folder.id)
    find("[title='#{I18n.t("home.files.new_md")}']").click

    assert_no_selector "input[value='#{old_note.title}']"
    assert_selector "textarea[name='note[content]']"
  end
end
