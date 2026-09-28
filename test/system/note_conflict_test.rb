require "application_system_test_case"

class NoteConflictTest < ApplicationSystemTestCase
  BANNER = "[data-note-conflict-target='banner']".freeze

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(notebook: @notebook, title: "Shared Note", note_type: "md", content: "")
  end

  test "two devices editing one note never silently overwrite each other" do
    b_text = "端末Bの編集 kept deliberately"

    phase "1 both devices open the same version" do
      sign_in_as(users(:one))
      visit_note
      using_session("device_b") do
        page.driver.browser.manage.window.resize_to(1400, 1000)
        sign_in_as(users(:one))
        visit_note
      end
    end

    phase "2 device A saves first" do
      fill_in "note[content]", with: "Written from device A"
      wait_for_content("Written from device A")
    end

    using_session("device_b") do
      phase "3 device B's stale save conflicts" do
        fill_in "note[content]", with: b_text
        assert_selector BANNER, visible: true, text: I18n.t("notes.conflict.message")
        assert_equal "Written from device A", @note.reload.content
      end

      phase "4 cancelling Reload keeps the local edit" do
        dismiss_confirm(I18n.t("notes.conflict.reload_confirm")) { click_on I18n.t("notes.conflict.reload") }
        assert_selector BANNER, visible: true
        assert_field "note[content]", with: b_text
      end

      phase "5 a failed Keep mine keeps the banner and toasts" do
        record_toasts
        force_fetch_rejection
        click_on I18n.t("notes.conflict.keep_mine")
        assert_selector ".toast.show", text: I18n.t("js.autosave.save_failed")
        assert_selector BANNER, visible: true
        assert_equal "Written from device A", @note.reload.content
      end

      phase "6 Keep mine wins once the network is back" do
        restore_fetch
        # The toast sits over the banner's buttons.
        find(".toast.show .btn-close").click
        assert_no_selector ".toast.show"
        click_on I18n.t("notes.conflict.keep_mine")
        assert_no_selector BANNER, visible: true
        wait_for_content(b_text)
      end
    end

    phase "7 device A now conflicts and Reload shows B's text" do
      fill_in "note[content]", with: "A again"
      assert_selector BANNER, visible: true
      accept_confirm(I18n.t("notes.conflict.reload_confirm")) { click_on I18n.t("notes.conflict.reload") }
      assert_selector "textarea[name='note[content]']", text: b_text
      assert_no_selector BANNER, visible: true
    end
  end

  private

    def visit_note
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    end

    def wait_for_content(expected)
      wait_until("autosave never persisted #{expected.inspect}") { @note.reload.content == expected }
    end
end
