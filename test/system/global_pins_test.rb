require "application_system_test_case"

class GlobalPinsTest < ApplicationSystemTestCase
  test "a note pinned in notebook A opens from the pinned section while notebook B is open" do
    user = users(:one)
    notebook_a = user.notebooks.create!(name: "Notebook A")
    folder_a = notebook_a.folders.create!(name: "Folder A")
    pinned = folder_a.notes.create!(notebook: notebook_a, title: "Pinned In A", note_type: "md", is_pinned: true)
    notebook_b = user.notebooks.create!(name: "Notebook B")
    folder_b = notebook_b.folders.create!(name: "Folder B")

    sign_in_as(user)
    visit root_url(notebook_id: notebook_b.id, folder_id: folder_b.id)

    within "#pinned-list" do
      click_on pinned.title
    end

    assert_selector "input[value='#{pinned.title}']"
  end
end
