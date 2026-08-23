require "application_system_test_case"

class I18nTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
  end

  test "switching language in Settings > Language persists, and the next page load reflects it" do
    visit root_url
    find("button[title='#{I18n.t("home.header.settings")}']").click

    within "#settingsModal" do
      click_on "Language"
      choose "日本語"
    end

    # The switch reloads the page client-side — rather than race that,
    # wait for the save to land server-side, then visit fresh ourselves.
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.1 until users(:one).reload.locale == "ja" }

    visit root_url
    # The gear icon's tooltip is Japanese now too — explicit locale: :ja
    # since this test process's own I18n.locale stays :en throughout.
    find("button[title='#{I18n.t("home.header.settings", locale: :ja)}']").click

    within "#settingsModal" do
      assert_text "設定"
      assert_text "エディタ"
      # Deliberately never translated, like the native-name radio labels —
      # a language switcher must stay findable by its English name.
      assert_text "Language"

      # A fresh page load always renders the Editor tab-pane active — the
      # Language pane only becomes visible once its tab is clicked.
      click_on "Language"
      assert_selector "input#localeJa[checked]"

      # The Account tab (password auth, the default fixture) — confirms
      # both the tab label and the relocated sign-out button are Japanese.
      click_on I18n.t("settings.tabs.account", locale: :ja)
      assert_text I18n.t("home.sign_out", locale: :ja)
    end
  end

  test "the sidebar renders in Japanese once that's the signed-in user's locale" do
    users(:one).update!(locale: "ja")
    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    notebook.folders.create!(name: "Test Folder")

    visit root_url(notebook_id: notebook.id)

    assert_text I18n.t("home.notebooks.heading", locale: :ja)
    assert_text I18n.t("home.folders.heading", locale: :ja)
    assert_text I18n.t("home.files.heading", locale: :ja)
    assert_selector "html[lang=ja]"
  end

  test "the md editor's toolbar renders in Japanese once that's the signed-in user's locale" do
    users(:one).update!(locale: "ja", compare_enabled: true)
    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "Test Folder")
    note = folder.notes.create!(title: "Note", content: "Hello", note_type: "md", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)

    assert_selector "button[title='#{I18n.t("editor.modes.edit_only", locale: :ja)}']"
    assert_selector "textarea[placeholder='#{I18n.t("editor.content_placeholder", locale: :ja)}']"
    assert_selector "button[title='#{I18n.t("editor.fab.button_title", locale: :ja)}']"
  end

  test "a Stimulus controller's own UI text (a toast) is in Japanese too, not just server-rendered copy" do
    users(:one).update!(locale: "ja")
    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "Test Folder")
    note = folder.notes.create!(title: "Note", content: "Hello", note_type: "md", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)

    # word_paste_controller.js reads this from <meta name="translations">
    # — confirms that path works end to end, not just the server half.
    page.driver.browser.execute_script(<<~JS)
      const dataTransfer = new DataTransfer()
      dataTransfer.setData("text/html", "<p>This is <b>bold</b>.</p>")
      dataTransfer.setData("text/plain", "This is bold.")

      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
    JS

    assert_selector ".toast.show", text: I18n.t("js.converted_to_markdown", locale: :ja)
  end
end
