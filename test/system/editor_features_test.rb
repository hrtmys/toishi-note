require "application_system_test_case"

class EditorFeaturesTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
  end

  test "3段階表示モードの切り替えとプレビューが機能すること" do
    # Create MD note data up front, then open that note's page.
    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "Test Folder")
    # Associate the notebook when creating the note too.
    note = folder.notes.create!(title: "MD Test Note", content: "Initial", note_type: "md", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)

    # 1. Confirm the initial state (split view).
    assert_selector "textarea[name='note[content]']", visible: true
    assert_selector ".markdown-content", visible: true

    # 2. Click the preview-only mode button.
    find("button[title='#{I18n.t("editor.modes.preview_only")}']").click

    # The textarea is hidden, the preview is visible.
    assert_selector "textarea[name='note[content]']", visible: false
    assert_selector ".markdown-content", visible: true

    # 3. Click the edit-only mode button.
    find("button[title='#{I18n.t("editor.modes.edit_only")}']").click

    # The preview is hidden, the textarea is visible.
    assert_selector "textarea[name='note[content]']", visible: true
    assert_selector ".markdown-content", visible: false

    # 4. Typing Markdown reflects into the preview immediately.
    find("button[title='#{I18n.t("editor.modes.split")}']").click

    # Fill in the form and verify it renders as HTML in the preview area.
    fill_in "note[content]", with: <<~MD
      # 爆速プレビューテスト

      $$x^2 + y^2 = z^2$$

      ```mermaid
      flowchart TD
        A[Start] --> B[End]
      ```
    MD

    assert_selector ".markdown-content h1", text: "爆速プレビューテスト"
    assert_selector ".markdown-content .katex"
    assert_selector ".markdown-content .mermaid svg"
  end

  test "scrap item でも KaTeX と Mermaid が描画されること" do
    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "Test Folder")
    note = folder.notes.create!(title: "Scrap Note", content: "Initial", note_type: "scrap", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)

    fill_in "content", with: <<~MD
      # Scrap Math and Mermaid

      $$a^2 + b^2 = c^2$$

      ```mermaid
      flowchart TD
        A[Start] --> B[End]
      ```
    MD

    click_button I18n.t("home.common.add")

    assert_selector "#scrap_list_#{note.id} h1", text: "Scrap Math and Mermaid"
    assert_selector "#scrap_list_#{note.id} .katex"
    assert_selector "#scrap_list_#{note.id} .mermaid svg"
  end

  test "リッチテキストコピーのボタンがMarkdownエディタに表示されること" do
    # The copy button lives inside the AI-formatting FAB, off by default —
    # set directly rather than driven through the UI; toggling itself is
    # covered by editor_fab_test.rb.
    users(:one).update!(editor_fab_enabled: true)

    notebook = users(:one).notebooks.create!(name: "Test Notebook")
    folder = notebook.folders.create!(name: "Test Folder")
    note = folder.notes.create!(title: "Copy Test Note", content: "# Copy test", note_type: "md", notebook: notebook)

    visit root_url(notebook_id: notebook.id, folder_id: folder.id, note_id: note.id)

    find(".editor-fab-button").click
    assert_selector "button[title='#{I18n.t("editor.fab.copy_for_word_title")}']", visible: true
  end
end
