require "application_system_test_case"

# Audit finding ux-ui #13 (remainder): changeLocale() used to reload the
# page unconditionally via .finally(), even when the save itself failed —
# showing a "save failed" toast and then reloading anyway, which
# re-displayed the OLD locale as if the save had actually landed.
class SettingsLocaleTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)
  end

  test "switching locale reloads the page once the save actually succeeds" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find("button[title='Settings']").click
    within "#settingsModal" do
      # The locale radios live in the Language tab-pane, which is hidden
      # until its tab is clicked (the Editor pane renders active) — without
      # this, choose finds no *visible* radio button.
      click_on "Language"
      choose "localeJa"
    end

    # A real reload is the only way the already-rendered "Settings" button
    # title picks up the new locale (it's plain server-rendered HTML, not
    # live-translated) — its Japanese text is proof the reload happened.
    assert_selector "button[title='設定']"
  end

  test "switching locale does NOT reload the page if the save fails" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    force_fetch_rejection

    find("button[title='Settings']").click
    within "#settingsModal" do
      # See above: the locale radios are in the hidden-until-clicked
      # Language tab-pane.
      click_on "Language"
      choose "localeJa"
    end

    assert_selector ".toast.show", text: I18n.t("js.settings.save_failed")

    # The critical assertion: still on the English UI (a reload after a
    # failed save used to flip this to Japanese even though nothing was
    # actually persisted), and the settings modal — which a reload would
    # tear down — is still right here, proof no navigation happened.
    assert_selector "#settingsModal.show"
    assert_selector "button[title='Settings']"
  end

  private

    def force_fetch_rejection
      page.execute_script(<<~JS)
        window.fetch = () => Promise.reject(new TypeError("Failed to fetch"))
      JS
    end
end
