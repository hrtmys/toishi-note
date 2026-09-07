require "application_system_test_case"

# Audit finding ux-ui #4: Notebook/Folder/Note create/rename/delete/move
# used to give no visible confirmation at all — success was silent, and a
# validation failure just bounced to a bare error response. These tests
# cover a representative slice of the 12 operations (not all of them)
# confirming the flash-bridged toast (see application.html.erb and
# app/javascript/controllers/flash_toast_controller.js) actually appears,
# plus one representative failure case.
class CrudFeedbackTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
  end

  test "creating a notebook from Organize shows a success toast" do
    visit root_url
    click_on "Toishi Note" # opens Organize

    accept_prompt(with: "Brand New Notebook") { click_on I18n.t("home.notebooks.new_prompt") }

    assert_selector ".toast.show", text: I18n.t("home.notebooks.flash.created")
    assert_text "Brand New Notebook"
  end

  test "renaming a folder shows a success toast" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    folder = notebook.folders.create!(name: "Old Folder Name")

    visit root_url(notebook_id: notebook.id, folder_id: folder.id)

    within "#folders-list" do
      # Sidebar rename/delete buttons are hover-revealed (hover-target-icon
      # is zero-width until its row is hovered) — without this, click_on
      # finds no visible button. Same pattern as note_sort_test.rb.
      find("li", text: "Old Folder Name").hover
      accept_prompt(with: "New Folder Name") { click_on I18n.t("home.common.rename") }
    end

    assert_selector ".toast.show", text: I18n.t("home.folders.flash.renamed")
    assert_text "New Folder Name"
  end

  test "deleting a note shows a success toast" do
    notebook = users(:one).notebooks.create!(name: "Notebook")
    folder = notebook.folders.create!(name: "Folder")
    # Named to avoid containing "Delete": click_on matches links by
    # substring, so a "Note To Delete" title link would also match (and win
    # while the real hover-revealed button is still hidden).
    note = folder.notes.create!(title: "Temporary Note", note_type: "md", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)

    within "#notes-list" do
      # Hover-revealed button — see the folder-rename test above.
      find("li", text: "Temporary Note").hover
      accept_confirm { click_on I18n.t("home.common.delete") }
    end

    assert_selector ".toast.show", text: I18n.t("home.notes.flash.deleted")
    assert_no_text "Temporary Note"
  end

  test "renaming a notebook to a blank name shows a failure toast and leaves the name unchanged" do
    notebook = users(:one).notebooks.create!(name: "Old Name")

    visit root_url(notebook_id: notebook.id)

    # prompt_form_controller.js refuses to submit a blank prompt value
    # client-side, so a blank rename can't be produced via the real
    # prompt() dialog — bypass it and submit the underlying form directly,
    # the same way a stripped-down or non-JS client could. Native submit
    # (not requestSubmit): requestSubmit fires the submit event, which
    # prompt-form handles by opening a window.prompt that Selenium then
    # trips over as an unexpected alert.
    page.execute_script(<<~JS, notebook_path(notebook))
      const form = document.querySelector(`form[action="${arguments[0]}"]`)
      form.querySelector('input[name="name"]').value = ""
      HTMLFormElement.prototype.submit.call(form)
    JS

    assert_selector ".toast.show", text: I18n.t("home.notebooks.flash.rename_failed")
    assert_equal "Old Name", notebook.reload.name
  end
end
