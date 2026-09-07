require "application_system_test_case"

# Audit finding ux-ui #1: several background-save paths used to fail
# completely silently (no toast, no banner) on a network error — a user on
# a flaky connection could keep editing into what looked like a working UI
# while nothing was actually being persisted. These tests force the
# underlying fetch to reject and assert a toast now surfaces instead.
class SilentSaveFailureTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "a network failure during autosave shows an error toast instead of failing silently" do
    note = @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    force_fetch_rejection

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("new content")

    assert_selector ".toast.show", text: I18n.t("js.autosave.save_failed")
  end

  test "a non-2xx, non-409 autosave response shows an error toast instead of an obscure JS error" do
    note = @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    force_fetch_status(500)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("new content")

    assert_selector ".toast.show", text: I18n.t("js.autosave.save_failed")
  end

  test "a network failure saving a scrap source shows an error toast instead of failing silently" do
    note = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
    item = note.scrap_items.create!(content: "From a chat")
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    force_fetch_rejection

    row = find("#scrap_item_#{item.id}")
    row.hover
    row.fill_in "source", with: "ChatGPT conversation"
    row.find_field("source").native.send_keys(:tab) # blur to trigger the change event

    assert_selector ".toast.show", text: I18n.t("js.scrap.source_save_failed")
  end

  test "a network failure saving a settings toggle shows an error toast instead of failing silently" do
    note = @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    force_fetch_rejection

    find("button[title='Settings']").click
    within "#settingsModal" do
      check "editorFabToggle"
    end

    assert_selector ".toast.show", text: I18n.t("js.settings.save_failed")
  end

  private

    # Replaces window.fetch with one that always rejects, simulating a
    # network failure (offline, DNS error, CORS, ...) rather than a valid
    # HTTP response.
    def force_fetch_rejection
      page.execute_script(<<~JS)
        window.fetch = () => Promise.reject(new TypeError("Failed to fetch"))
      JS
    end

    # Replaces window.fetch with one that resolves to a non-ok response
    # carrying the given status, simulating a server-side failure (e.g. 500)
    # rather than a rejected fetch.
    def force_fetch_status(status)
      page.execute_script(<<~JS)
        window.fetch = () => Promise.resolve(new Response("", { status: #{status}, headers: {} }))
      JS
    end
end
