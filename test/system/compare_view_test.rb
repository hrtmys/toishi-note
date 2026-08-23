require "application_system_test_case"

class CompareViewTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Compare Note", content: "The quick brown fox", note_type: "md", notebook: @notebook)
  end

  test "the FAB stays hidden until either toggle is on, and shows only the enabled feature's menu items" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    assert_no_selector ".editor-fab-button", visible: true

    users(:one).update!(compare_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find(".editor-fab-button").click
    assert_selector "button", text: I18n.t("editor.fab.compare_as_before")
    assert_no_selector "button", text: I18n.t("editor.fab.quick_formatting")
  end

  test "toggling either Settings switch shows the FAB immediately, without a reload" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    assert_no_selector ".editor-fab-button", visible: true

    find("button[title='#{I18n.t("home.header.settings")}']").click
    within "#settingsModal" do
      check "compareToggle"
    end

    assert_selector ".editor-fab-button", visible: true
  end

  test "'Set as Before' and 'Set as After' load the note's current content and open the Compare modal" do
    users(:one).update!(compare_enabled: true)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find(".editor-fab-button").click
    click_on I18n.t("editor.fab.compare_as_before")

    assert_selector "#compareModal.show"
    within "#compareModal" do
      assert_equal "The quick brown fox", find("#compareBefore").value
      assert_equal "", find("#compareAfter").value
    end
  end

  test "pasting text into Before/After highlights the word-level diff between them" do
    open_compare_modal

    within "#compareModal" do
      set_field "#compareBefore", "The quick brown fox"
      set_field "#compareAfter", "The quick red fox jumps"

      assert_no_text I18n.t("compare.empty")
      assert_selector "del.diff-removed", text: "brown"
      assert_selector "ins.diff-added", text: "red"
      assert_selector "ins.diff-added", text: "jumps"
    end
  end

  test "identical Before/After text shows an explicit 'no differences' message" do
    open_compare_modal

    within "#compareModal" do
      set_field "#compareBefore", "Same text"
      set_field "#compareAfter", "Same text"

      assert_text I18n.t("compare.unchanged")
      assert_no_selector "ins.diff-added"
      assert_no_selector "del.diff-removed"
    end
  end

  test "Clear empties both boxes and the diff output" do
    open_compare_modal

    within "#compareModal" do
      set_field "#compareBefore", "Before text"
      set_field "#compareAfter", "After text"
      assert_selector "ins.diff-added"

      click_on I18n.t("compare.clear")

      assert_equal "", find("#compareBefore").value
      assert_equal "", find("#compareAfter").value
      assert_text I18n.t("compare.empty")
      assert_no_selector "ins.diff-added"
    end
  end

  test "applying Quick Formatting loads its before/after into the Compare modal" do
    users(:one).update!(editor_fab_enabled: true, compare_enabled: true)
    @note.update!(content: "Amount: １２３")
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    find(".editor-fab-button").click
    assert_selector "button", text: I18n.t("editor.fab.quick_formatting")
    click_on I18n.t("editor.fab.quick_formatting")
    check "fmtFullwidth"
    click_on I18n.t("editor.fab.apply")

    # Quick Formatting never opens the modal — open it via "Set as After".
    # This overwrites After only, leaving Before as its own dispatch set it.
    click_on I18n.t("editor.fab.compare_as_after")

    within "#compareModal" do
      assert_equal "Amount: １２３", find("#compareBefore").value
      assert_equal "Amount: 123", find("#compareAfter").value
      assert_selector "del.diff-removed", text: "１２３"
      assert_selector "ins.diff-added", text: "123"
    end
  end

  private
    # `open_compare_modal` leaves a field populated via `.value =`.
    # Capybara's `.set()` occasionally fails to clear that before typing
    # (a Selenium quirk) — an explicit clear first avoids it.
    def set_field(selector, value)
      field = find(selector)
      field.set("")
      field.set(value)
    end

    # Opens the Compare modal via the real FAB flow rather than driving
    # Bootstrap's JS API directly — `bootstrap` isn't a page-global.
    def open_compare_modal
      users(:one).update!(compare_enabled: true)
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

      find(".editor-fab-button").click
      click_on I18n.t("editor.fab.compare_as_before")
      assert_selector "#compareModal.show"
    end
end
