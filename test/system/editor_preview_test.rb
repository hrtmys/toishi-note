require "application_system_test_case"

class EditorPreviewTest < ApplicationSystemTestCase
  TEXTAREA = "textarea[name='note[content]']".freeze
  PREVIEW_AREA = "[data-editor-target='previewArea']".freeze

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

    phase "4a typing mid-note brings its block into view and keeps it there across the diagram re-render" do
      execute_script(<<~JS, long_markdown)
        const ta = document.querySelector("#{TEXTAREA}")
        ta.value = arguments[0]
        ta.dispatchEvent(new Event("input", { bubbles: true }))
      JS
      assert_selector ".markdown-content h2", text: "Section 0"
      assert_selector ".markdown-content .mermaid svg"
      execute_script(<<~JS)
        document.querySelector("#{PREVIEW_AREA}").scrollTop = 0
        const ta = document.querySelector("#{TEXTAREA}")
        ta.focus()
        const caret = ta.value.indexOf("Body paragraph 30 ") + "Body paragraph 30".length
        ta.setSelectionRange(caret, caret)
        document.execCommand("insertText", false, "x")
      JS
      wait_until("the typed paragraph never rendered") { preview_text?("Body paragraph 30x") }
      wait_until("the re-rendered diagram never landed") { diagram_landed? }
      assert paragraph_in_preview_viewport?("Body paragraph 30x"), "the typed block is outside the preview viewport"
    end

    phase "4b preview follows the editor" do
      execute_script("const ta = document.querySelector(\"#{TEXTAREA}\"); ta.scrollTop = ta.scrollHeight")
      wait_until("the preview did not follow the editor to the bottom") { preview_ratio > 0.9 }
    end

    phase "4c a short note's preview follows typing at the end; a manual preview scroll wins until the next keystroke" do
      execute_script(<<~JS, short_flowchart_markdown)
        const ta = document.querySelector("#{TEXTAREA}")
        ta.value = arguments[0]
        ta.dispatchEvent(new Event("input", { bubbles: true }))
      JS
      assert_selector ".markdown-content .mermaid svg"
      assert_not overflows?(TEXTAREA), "the editor overflows, so this is not a short note"
      assert overflows?(PREVIEW_AREA), "the preview does not overflow, so there is nothing to follow"

      execute_script("document.querySelector(\"#{PREVIEW_AREA}\").scrollTop = 0")
      execute_script(<<~JS)
        const ta = document.querySelector("#{TEXTAREA}")
        ta.focus()
        ta.setSelectionRange(ta.value.length, ta.value.length)
      JS
      find(TEXTAREA).send_keys("\nnew last line")
      wait_until("the typed line never came into the preview viewport") { paragraph_in_preview_viewport?("new last line") }

      execute_script(<<~JS)
        const ta = document.querySelector("#{TEXTAREA}")
        ta.focus()
        ta.setSelectionRange(ta.value.length, ta.value.length)
        document.execCommand("insertText", false, "!")
        document.querySelector("#{PREVIEW_AREA}").scrollTop = 0
      JS
      wait_until("the typed exclamation mark never rendered") { preview_text?("new last line!") }
      assert_operator preview_scroll_top, :<, 5, "the follow pulled the preview back after a manual scroll"
    end
    phase "5 typing at the end of a long code block keeps the typed line in the preview viewport" do
      { "closed, last" => code_markdown(close: true),
        "unclosed, last" => code_markdown(close: false),
        "closed, mid-note" => code_markdown(close: true, after: true) }.each do |label, markdown|
        execute_script(<<~JS, markdown)
          const ta = document.querySelector("#{TEXTAREA}")
          ta.value = arguments[0]
          ta.dispatchEvent(new Event("input", { bubbles: true }))
          document.querySelector("#{PREVIEW_AREA}").scrollTop = 0
        JS
        assert_selector ".markdown-content pre", text: "code line 80"
        execute_script(<<~JS)
          const ta = document.querySelector("#{TEXTAREA}")
          ta.focus()
          const caret = ta.value.indexOf("code line 80") + "code line 80".length
          ta.setSelectionRange(caret, caret)
        JS
        find(TEXTAREA).send_keys("\ncode line 80x")
        wait_until("#{label}: the typed code line never came into the preview viewport") { text_in_preview_viewport?("code line 80x") }
      end
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

  # Three source lines, 24 nodes stacked top to bottom: a tall diagram in a short note.
  def short_flowchart_markdown
    chain = ->(from, to) { (from..to).map { |i| "N#{i}" }.join("-->") }
    "```mermaid\nflowchart TD\n  #{chain.call(1, 12)}\n  #{chain.call(12, 24)}\n```\n\nend line"
  end

  def code_markdown(close:, after: false)
    lines = (1..80).map { |i| "code line #{i}" }.join("\n")
    md = "# Code\n\nintro\n\n```js\n#{lines}\n"
    md += "```\n" if close
    md += "\n" + Array.new(30) { |i| "Tail paragraph #{i}.\n" }.join("\n") if after
    md
  end

  # Whether the rendered text itself (not its whole block) lies inside the preview's visible area.
  def text_in_preview_viewport?(text)
    evaluate_script(<<~JS)
      (() => {
        const preview = document.querySelector("#{PREVIEW_AREA}")
        // Highlighting splits a line across spans, so map the match back through every text node.
        const at = preview.textContent.indexOf(#{text.to_json})
        if (at === -1) return false
        const range = document.createRange()
        const walker = document.createTreeWalker(preview, NodeFilter.SHOW_TEXT)
        let offset = 0
        while (walker.nextNode()) {
          const node = walker.currentNode
          const end = offset + node.data.length
          if (offset <= at && at < end) range.setStart(node, at - offset)
          if (offset < at + #{text.length} && at + #{text.length} <= end) {
            range.setEnd(node, at + #{text.length} - offset)
            const view = preview.getBoundingClientRect()
            const rect = range.getBoundingClientRect()
            return rect.top >= view.top && rect.bottom <= view.bottom
          }
          offset = end
        }
        return false
      })()
    JS
  end

  def overflows?(selector)
    evaluate_script("(() => { const el = document.querySelector(#{selector.to_json}); return el.scrollHeight > el.clientHeight })()")
  end

  def preview_scroll_top
    evaluate_script("document.querySelector(\"#{PREVIEW_AREA}\").scrollTop")
  end

  def preview_text?(text)
    evaluate_script("document.querySelector(\"#{PREVIEW_AREA}\").textContent.includes(#{text.to_json})")
  end

  def diagram_landed?
    evaluate_script(<<~JS)
      (() => {
        const content = document.querySelector(".markdown-content")
        return content.querySelector(".mermaid svg") !== null && content.querySelector("pre code.language-mermaid") === null
      })()
    JS
  end

  # Whether the paragraph holding the text lies fully inside the preview's visible area.
  def paragraph_in_preview_viewport?(text)
    evaluate_script(<<~JS)
      (() => {
        const preview = document.querySelector("#{PREVIEW_AREA}")
        const paragraph = [ ...preview.querySelectorAll("p") ].find((p) => p.textContent.includes(#{text.to_json}))
        if (!paragraph) return false
        const view = preview.getBoundingClientRect()
        const rect = paragraph.getBoundingClientRect()
        return rect.top >= view.top && rect.bottom <= view.bottom
      })()
    JS
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
