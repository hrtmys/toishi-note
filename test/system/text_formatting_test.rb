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

    find(".editor-fab-button").click
    find("button[title='#{I18n.t("editor.fab.quick_formatting_title")}']").click
    assert_selector ".editor-fab-submenu:not(.d-none)"

    # All five keys in one shot: a typo silently disables one transform.
    # Each transform alone lives in test/javascript/text_format.test.js.
    find("#fmtFullwidth").check
    find("#fmtPunct").check
    find("#fmtNumJp").check
    find("#fmtNewlines").check
    find("#fmtBrackets").check

    find("button", text: I18n.t("editor.fab.apply")).click

    assert_equal "1234567890\n1000と 文字 の間 の 空白\n行1行2\n",
      find("textarea[name='note[content]']").value
  end
end
