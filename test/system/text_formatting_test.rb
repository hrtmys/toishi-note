require "application_system_test_case"

class TextFormattingTest < ApplicationSystemTestCase
  setup do
    # Use a larger window to ensure all elements are visible
    page.driver.browser.manage.window.resize_to(1400, 1000)
    # Quick formatting lives inside the AI-formatting FAB, which is off by
    # default (see Settings > Editor) — enabling it isn't what this test is
    # about, so it's set directly rather than driven through the UI.
    users(:one).update!(editor_fab_enabled: true)
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Formatting Note", content: <<~MD, note_type: "md", notebook: @notebook)
      １２３４５６７８９０
      1000 と 文字 の間 の 空白
      行1\n\n\n行2
      [削除したい]
    MD
  end

  test "text formatting modal applies selected transformations" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    # Open the FAB, then the formatting submenu inside it
    find(".editor-fab-button").click
    find("button[title='#{I18n.t("editor.fab.quick_formatting_title")}']").click

    # Wait for the submenu itself, not just its first checkbox — a plain
    # d-none check can pass a beat before layout of the unhidden subtree finishes.
    assert_selector ".editor-fab-submenu:not(.d-none)"

    # Select all transformation options
    find("#fmtFullwidth").check
    find("#fmtPunct").check
    find("#fmtNumJp").check
    find("#fmtNewlines").check
    find("#fmtBrackets").check

    # Apply formatting
    find("button", text: I18n.t("editor.fab.apply")).click

    # Verify textarea content has been transformed
    textarea = find("textarea[name='note[content]']")
    value = textarea.value

    # Fullwidth digits -> halfwidth digits
    assert_match /1234567890/, value
    # Removes the space between a number and Japanese text ("1000 と" -> "1000と")
    assert_no_match /1000\s+と/, value
    # Collapses consecutive blank lines into one
    assert_no_match /\n{2,}/, value
    # Removes text wrapped in []
    assert_no_match /\[削除したい\]/, value
  end
end
