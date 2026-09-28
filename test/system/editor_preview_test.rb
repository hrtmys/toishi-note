require "application_system_test_case"

class EditorPreviewTest < ApplicationSystemTestCase
  TEXTAREA = "textarea[name='note[content]']".freeze

  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Preview Note", content: "Initial", note_type: "md", notebook: @notebook)
  end

  test "the md preview switches modes, renders KaTeX and Mermaid under burst typing, and keeps scroll in sync" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    phase "1 modes" do
      assert_selector TEXTAREA, visible: true
      assert_selector ".markdown-content", visible: true
      click_mode "preview_only"
      assert_selector TEXTAREA, visible: :hidden
      assert_selector ".markdown-content", visible: true
      click_mode "edit_only"
      assert_selector TEXTAREA, visible: true
      assert_selector ".markdown-content", visible: :hidden
      click_mode "split"
      assert_selector ".markdown-content", visible: true
    end

    # The first diagram in this document starts the Mermaid chunk import; network
    # latency keeps it in flight past the next debounced render.
    phase "2 burst typing during the lazy import" do
      fill_in "note[content]", with: ""
      textarea = find(TEXTAREA)
      page.driver.browser.network_conditions = { offline: false, latency: 300, throughput: 0 }
      textarea.send_keys("# Burst diagram\n\n")
      textarea.send_keys("```mermaid\n")
      textarea.send_keys("flowchart TD\n")
      assert_selector ".markdown-content pre code.language-mermaid"
      textarea.send_keys("  A[Start] --> B[End]\n")
      textarea.send_keys("```\n")
      assert_selector ".markdown-content .mermaid svg"
    ensure
      page.driver.browser.delete_network_conditions
    end

    phase "3 KaTeX and mermaid render" do
      fill_in "note[content]", with: <<~MD
        # 爆速プレビューテスト

        $$x^2 + y^2 = z^2$$

        ```mermaid
        this is not a diagram {{{
        ```

        ```mermaid
        flowchart TD
          A[Start] --> B[End]
        ```
      MD
      # Blocks render in document order, so the valid svg means the invalid block was already handled.
      assert_selector ".markdown-content .mermaid svg", count: 1
      assert_selector ".markdown-content h1", text: "爆速プレビューテスト"
      assert_selector ".markdown-content .katex"
      assert_selector ".markdown-content pre code.language-mermaid", count: 1
      assert_selector ".markdown-content .mermaid svg", count: 1
    end

    phase "4a scroll kept across re-render" do
      execute_script(<<~JS, long_markdown)
        const ta = document.querySelector("#{TEXTAREA}")
        ta.value = arguments[0]
        ta.dispatchEvent(new Event("input", { bubbles: true }))
      JS
      assert_selector ".markdown-content h2", text: "Section 0"
      assert_selector ".markdown-content .mermaid svg"
      execute_script(<<~JS)
        const preview = document.querySelector("[data-editor-target='previewArea']")
        preview.scrollTop = (preview.scrollHeight - preview.clientHeight) * 0.5
      JS
      ratio_before = preview_ratio
      assert_in_delta 0.5, ratio_before, 0.05, "the preview could not be parked mid-document"
      execute_script(<<~JS)
        const ta = document.querySelector("#{TEXTAREA}")
        ta.value = ta.value + "\\nAppended scroll probe line\\n"
        ta.dispatchEvent(new Event("input", { bubbles: true }))
      JS
      assert_selector ".markdown-content", text: "Appended scroll probe line"
      # The re-rendered diagram grows the content above the viewport, the late insert that used to drift the view.
      assert_selector ".markdown-content .mermaid svg"
      ratio_after = preview_ratio
      assert_in_delta ratio_before, ratio_after, 0.05, "re-render moved the preview"
      assert_operator ratio_after, :<, 0.75, "the preview drifted toward the bottom"
    end

    phase "4b preview follows the editor" do
      execute_script("const ta = document.querySelector(\"#{TEXTAREA}\"); ta.scrollTop = ta.scrollHeight")
      wait_until("the preview did not follow the editor to the bottom") { preview_ratio > 0.9 }
    end
  end

  private

  def click_mode(mode)
    find("button[title='#{I18n.t("editor.modes.#{mode}")}']").click
  end

  # A tall diagram at the top, so its async render changes the height above a mid-document view.
  def long_markdown
    diagram = "```mermaid\nflowchart TD\n  #{(1..12).map { |i| "N#{i}" }.join(" --> ")}\n```\n"
    sections = Array.new(40) { |i| "## Section #{i}\n\nBody paragraph #{i} with some text to take vertical space.\n" }
    ([ diagram ] + sections).join("\n")
  end

  # -1 means the preview is not scrollable at all, a setup failure rather than a pass.
  def preview_ratio
    evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-editor-target='previewArea']")
        const max = el.scrollHeight - el.clientHeight
        return max <= 0 ? -1 : el.scrollTop / max
      })()
    JS
  end
end
