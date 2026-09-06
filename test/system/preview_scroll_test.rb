require "application_system_test_case"

# Regression coverage for preview scroll drift: every keystroke replaces
# the preview's innerHTML wholesale, which used to let the view drift
# downward while typing (and jitter at the bottom as Mermaid/KaTeX
# inserts landed late). The editor controller now pins the relative
# scroll position across re-renders and follows the editor proportionally.
class PreviewScrollTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Scroll Note", content: "Initial", note_type: "md", notebook: @notebook)
  end

  test "typing keeps the preview at the same relative scroll position" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    fill_in "note[content]", with: long_markdown
    assert_selector ".markdown-content h2", text: "Section 0"

    # Park the preview mid-document, then re-render via an input event
    # without moving the caret or scrolling the textarea, so only the
    # save/restore path is exercised.
    page.execute_script(<<~JS)
      const preview = document.querySelector("[data-editor-target='previewArea']")
      preview.scrollTop = (preview.scrollHeight - preview.clientHeight) * 0.5
    JS
    ratio_before = preview_ratio
    assert_in_delta 0.5, ratio_before, 0.05

    page.execute_script(<<~JS)
      const ta = document.querySelector("textarea[name='note[content]']")
      ta.value = ta.value + "\\nAppended scroll probe line\\n"
      ta.dispatchEvent(new Event("input", { bubbles: true }))
    JS
    assert_selector ".markdown-content", text: "Appended scroll probe line"

    ratio_after = preview_ratio
    assert_in_delta ratio_before, ratio_after, 0.05
    assert_operator ratio_after, :<, 0.75, "preview drifted toward the bottom while typing"
  end

  test "scrolling the editor follows proportionally in the preview" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    fill_in "note[content]", with: long_markdown
    assert_selector ".markdown-content h2", text: "Section 0"
    assert_in_delta 0.0, preview_ratio, 0.05

    page.execute_script(<<~JS)
      const ta = document.querySelector("textarea[name='note[content]']")
      ta.scrollTop = ta.scrollHeight
    JS

    followed = Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        ratio = preview_ratio
        break ratio if ratio > 0.9
        sleep 0.05
      end
    end
    assert_operator followed, :>, 0.9, "preview did not follow the editor to the bottom"
  end

  private

  def long_markdown
    Array.new(120) { |i| "## Section #{i}\n\nBody paragraph #{i} with some text to take vertical space.\n" }.join("\n")
  end

  # Relative scroll position: 0.0 is top, 1.0 is bottom, -1 means the
  # preview is not scrollable at all (test setup failure, not a pass).
  def preview_ratio
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("[data-editor-target='previewArea']")
        const max = el.scrollHeight - el.clientHeight
        return max <= 0 ? -1 : el.scrollTop / max
      })()
    JS
  end
end
