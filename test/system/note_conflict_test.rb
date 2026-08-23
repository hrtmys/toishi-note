require "application_system_test_case"

# Drives two separate browser sessions (using_session spins up its own
# Chrome window with its own cookie jar) to reproduce the bug this fixes:
# autosave used to PUT with no version check, last save silently winning.
class NoteConflictTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Shared Note", note_type: "md", content: "")
  end

  test "a device that saves second, after another device already saved, is shown a conflict instead of silently overwriting" do
    sign_in_as(users(:one))
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    using_session("device_b") do
      page.driver.browser.manage.window.resize_to(1400, 1000)
      sign_in_as(users(:one))
      # Loads the note at the same starting lock_version device A has —
      # both devices now hold the same "version 0" snapshot, exactly
      # like two real devices open to the same note at the same time.
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    end

    # Device A edits and saves first; wait for its autosave to actually
    # land (a real 500ms-debounced network round trip, not instant).
    fill_in "note[content]", with: "Written from device A"
    wait_for_content("Written from device A")

    using_session("device_b") do
      # Device B never reloaded, so its page still carries the lock_version
      # it originally loaded with — stale now that device A has saved.
      fill_in "note[content]", with: "Written from device B"
      assert_selector "[data-note-conflict-target='banner']", visible: true, text: I18n.t("notes.conflict.message")
    end

    # The critical assertion: device B's conflicting save never silently
    # applied. Device A's content is still what's actually persisted.
    assert_equal "Written from device A", @note.reload.content
  end

  test "Reload discards the local edit and shows what's actually on the server" do
    sign_in_as(users(:one))
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    using_session("device_b") do
      page.driver.browser.manage.window.resize_to(1400, 1000)
      sign_in_as(users(:one))
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    end

    fill_in "note[content]", with: "Server truth after device A"
    wait_for_content("Server truth after device A")

    using_session("device_b") do
      fill_in "note[content]", with: "Device B's now-conflicting edit"
      assert_selector "[data-note-conflict-target='banner']", visible: true

      click_on I18n.t("notes.conflict.reload")

      assert_selector "textarea[name='note[content]']", text: "Server truth after device A"
    end
  end

  test "Keep mine resubmits the local edit and it wins, deliberately overwriting the other device" do
    sign_in_as(users(:one))
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    using_session("device_b") do
      page.driver.browser.manage.window.resize_to(1400, 1000)
      sign_in_as(users(:one))
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    end

    fill_in "note[content]", with: "Device A's edit"
    wait_for_content("Device A's edit")

    using_session("device_b") do
      fill_in "note[content]", with: "Device B's edit, kept deliberately"
      assert_selector "[data-note-conflict-target='banner']", visible: true

      click_on I18n.t("notes.conflict.keep_mine")

      assert_no_selector "[data-note-conflict-target='banner']", visible: true
    end

    wait_for_content("Device B's edit, kept deliberately")
    assert_equal "Device B's edit, kept deliberately", @note.reload.content
  end

  private

  def wait_for_content(expected)
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.1 until @note.reload.content == expected }
  end
end
