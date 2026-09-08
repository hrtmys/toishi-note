require "application_system_test_case"

# Audit finding ux-ui #10: an empty notebooks/folders/notes list used to
# just render a blank area with no explanation — confusing for a first-time
# user, or anyone who just deleted everything. These assert the new
# empty-state messages actually show up in each of those situations.
class SidebarEmptyStatesTest < ApplicationSystemTestCase
  test "a folder with zero notes shows an empty-state message instead of a blank list" do
    user = users(:one)
    notebook = user.notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "Empty Folder")

    sign_in_as(user)
    visit root_url(notebook_id: notebook.id, folder_id: folder.id)

    within "#notes-list" do
      assert_text I18n.t("home.files.empty")
    end
  end

  test "a notebook with zero folders shows an empty-state message, and no 'select a folder' prompt for new notes" do
    user = users(:one)
    notebook = user.notebooks.create!(name: "Folderless Notebook")

    sign_in_as(user)
    visit root_url(notebook_id: notebook.id)

    within "#folders-list" do
      assert_text I18n.t("home.folders.empty")
    end
    assert_text I18n.t("home.files.no_folder_selected")
  end

  test "a user with no notebooks at all sees guidance instead of a blank folders panel" do
    user = users(:one)
    user.notebooks.destroy_all

    sign_in_as(user)
    visit root_url

    within "#folders-list" do
      assert_text I18n.t("home.folders.no_notebook_selected")
    end
  end
end
