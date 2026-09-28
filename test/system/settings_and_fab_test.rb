require "application_system_test_case"

class SettingsAndFabTest < ApplicationSystemTestCase
  FAB = ".editor-fab-button".freeze

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    @user = users(:one)
    @user.update!(editor_fab_enabled: false, compare_enabled: false, table_paste_enabled: false, locale: "en")
    @notebook = @user.notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "FAB Note", content: "Amount: １２３", note_type: "md", notebook: @notebook)
    sign_in_as @user
  end

  test "Settings apply live and fail loudly, the locale reloads only after a saved switch, and FAB tools work in Japanese" do
    phase "1 the FAB starts hidden" do
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
      record_toasts
      assert_no_selector FAB, visible: true
      # Survives only as long as this document does, so it proves no reload happened.
      execute_script("window.__sameDocument = true")
    end

    phase "2 enabling the FAB shows it without a reload" do
      find("button[title='#{I18n.t("home.header.settings")}']").click
      within("#settingsModal") { check "editorFabToggle" }
      assert_selector FAB, visible: true
      assert same_document?, "enabling the FAB reloaded the page"
      wait_until("editor_fab_enabled never saved") { @user.reload.editor_fab_enabled? }
    end

    phase "3 enabling Compare saves" do
      within("#settingsModal") { check "compareToggle" }
      wait_until("compare_enabled never saved") { @user.reload.compare_enabled? }
    end

    phase "4 a failed toggle save toasts" do
      force_fetch_rejection
      within("#settingsModal") { check "tablePasteToggle" }
      assert_selector ".toast.show", text: I18n.t("js.settings.save_failed")
      assert_toast I18n.t("js.settings.save_failed")
      assert_not @user.reload.table_paste_enabled?
    end

    phase "5 a failed locale save doesn't reload" do
      within("#settingsModal") do
        click_on "Language"
        choose "localeJa"
      end
      assert_toast I18n.t("js.settings.save_failed")
      assert_selector "#settingsModal.show"
      assert_selector "button[title='Settings']"
      assert same_document?, "a failed locale save reloaded the page"
    end

    phase "6 a saved locale switch reloads into Japanese" do
      restore_fetch
      # Puts the radios back to their pre-attempt state, so choosing ja fires change again.
      execute_script("document.querySelector('#localeEn').checked = true")
      within("#settingsModal") { choose "localeJa" }
      assert_selector "button[title='#{I18n.t("home.header.settings", locale: :ja)}']"
      assert_equal "ja", @user.reload.locale
    end

    phase "7 FAB styling and Copy for Word in Japanese" do
      record_toasts
      fab = find(FAB)
      fab.hover
      # bg-white's !important once blocked the hover invert, leaving white on white.
      assert_not_equal "rgb(255, 255, 255)", evaluate_script("getComputedStyle(document.querySelector('#{FAB}')).backgroundColor")
      fab.click
      assert_selector "#{FAB}.active"
      fab.click
      assert_no_selector "#{FAB}.active"

      fab.click
      click_on I18n.t("editor.fab.copy_for_word", locale: :ja)
      assert_toast I18n.t("js.copied", locale: :ja)
    end

    phase "8 Compare: Set as Before, diff and Clear" do
      click_on I18n.t("editor.fab.compare_as_before", locale: :ja)
      assert_selector "#compareModal.show"
      within "#compareModal" do
        assert_equal "Amount: １２３", find("#compareBefore").value
        assert_equal "", find("#compareAfter").value
        find("#compareAfter").set("Amount: 123")
        assert_selector "del.diff-removed", text: "１２３"
        assert_selector "ins.diff-added", text: "123"
        click_on I18n.t("compare.clear", locale: :ja)
        assert_equal "", find("#compareBefore").value
        assert_equal "", find("#compareAfter").value
        assert_text I18n.t("compare.empty", locale: :ja)
      end
      close_compare_modal
    end

    phase "9 Quick formatting feeds Compare" do
      find(FAB).click if has_no_selector?(".editor-fab-menu:not(.d-none)", wait: 0)
      click_on I18n.t("editor.fab.quick_formatting", locale: :ja)
      check "fmtFullwidth"
      click_on I18n.t("editor.fab.apply", locale: :ja)
      assert_field "note[content]", with: "Amount: 123"
      click_on I18n.t("editor.fab.compare_as_after", locale: :ja)
      within "#compareModal" do
        assert_equal "Amount: １２３", find("#compareBefore").value
        assert_equal "Amount: 123", find("#compareAfter").value
        assert_selector "del.diff-removed", text: "１２３"
        assert_selector "ins.diff-added", text: "123"
      end
      close_compare_modal
    end

    phase "10 a clipboard failure toasts in Japanese" do
      execute_script(<<~JS)
        Object.defineProperty(navigator, "clipboard", {
          value: { write: () => Promise.reject(new Error("denied")) },
          configurable: true,
        })
      JS
      find(FAB).click if has_no_selector?(".editor-fab-menu:not(.d-none)", wait: 0)
      copy = find("button[title='#{I18n.t("editor.fab.copy_for_word_title", locale: :ja)}']")
      # The button stays disabled for 1.5s after the previous copy.
      wait_until("the copy button never re-enabled") { !copy.disabled? }
      copy.click
      assert_toast I18n.t("js.word_copy.copy_failed", locale: :ja)
    end
  end

  private

    def same_document?
      evaluate_script("window.__sameDocument === true")
    end

    # Bootstrap ignores hide() while its show transition is still running.
    def close_compare_modal
      wait_until("the compare modal never closed") do
        find("#compareModal .btn-close").click
        has_no_selector?("#compareModal.show", wait: 0.3)
      end
    end
end
