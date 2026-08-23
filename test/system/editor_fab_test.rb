require "application_system_test_case"

class EditorFabTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "FAB Note", content: "# Hello", note_type: "md", notebook: @notebook)
  end

  test "the FAB is hidden until enabled in Settings, and appears immediately without a reload" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    assert_no_selector ".editor-fab-button", visible: true

    find("button[title='Settings']").click
    assert_selector "#settingsModal.show"

    within "#settingsModal" do
      check "editorFabToggle"
    end

    # No reload happened — Turbo/Capybara would otherwise reset the page.
    assert_selector ".editor-fab-button", visible: true
  end

  test "the choice persists across reloads once saved" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find("button[title='Settings']").click
    within "#settingsModal" do
      check "editorFabToggle"
    end

    # The toggle's PATCH is fire-and-forget from the browser's perspective —
    # nothing in the UI confirms it landed — so poll the database briefly
    # rather than reloading on a race against an in-flight request.
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.1 until users(:one).reload.editor_fab_enabled?
    end

    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    assert_selector ".editor-fab-button", visible: true
  end

  test "opening the FAB reveals Copy for Word and Quick formatting, and copying shows a toast" do
    users(:one).update!(editor_fab_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find(".editor-fab-button").click
    assert_selector "button[title='#{I18n.t("editor.fab.quick_formatting_title")}']"

    click_on I18n.t("editor.fab.copy_for_word")
    assert_selector ".toast.show", text: I18n.t("js.copied")
  end

  test "hovering the FAB button keeps its icon visible, rather than white-on-white" do
    users(:one).update!(editor_fab_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    fab_button = find(".editor-fab-button")
    fab_button.hover

    # `bg-white`'s `!important` previously blocked Bootstrap's hover
    # invert, rendering white-on-white — see _editor_fab.scss.
    background = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector(".editor-fab-button")).backgroundColor
    JS
    assert_not_equal "rgb(255, 255, 255)", background
  end

  test "the FAB button matches the app's outline-button style, and shows itself pressed while open" do
    users(:one).update!(editor_fab_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    fab_button = find(".editor-fab-button")
    assert fab_button[:class].include?("btn-outline-secondary"), "expected the FAB to reuse the app's outline-secondary button style"
    assert_not fab_button[:class].include?("active")

    fab_button.click
    assert_selector ".editor-fab-button.active"

    fab_button.click
    assert_no_selector ".editor-fab-button.active"
  end
end
