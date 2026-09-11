require "application_system_test_case"

class EditorShortcutsTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "Ctrl+B wraps the selection in bold markers" do
    visit_note(create_note)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("hello")
    textarea.send_keys([ :control, "a" ])
    textarea.send_keys([ :control, "b" ])

    assert_equal "**hello**", textarea.value
  end

  test "Ctrl+I wraps a Japanese selection in italic markers" do
    visit_note(create_note)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("こんにちは")
    textarea.send_keys([ :control, "a" ])
    textarea.send_keys([ :control, "i" ])

    assert_equal "*こんにちは*", textarea.value
  end

  test "Ctrl+B with no selection inserts a fenced pair and parks the caret between" do
    visit_note(create_note)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys([ :control, "b" ])
    textarea.send_keys("bold")

    assert_equal "**bold**", textarea.value
  end

  test "Ctrl+K with a selection builds a link and selects the url placeholder" do
    visit_note(create_note)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("hello")
    textarea.send_keys([ :control, "a" ])
    textarea.send_keys([ :control, "k" ])

    assert_equal "[hello](url)", textarea.value
    assert_equal "url", selected_text
  end

  test "Ctrl+K with no selection inserts a link skeleton and selects the text placeholder" do
    visit_note(create_note)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys([ :control, "k" ])

    assert_equal "[text](url)", textarea.value
    assert_equal "text", selected_text
  end

  test "Ctrl+Shift+K deletes the caret line without leaving a blank line" do
    visit_note(create_note)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("aaa")
    textarea.send_keys(:enter)
    textarea.send_keys("bbb")
    textarea.send_keys(:enter)
    textarea.send_keys("ccc")
    textarea.send_keys(:arrow_up)
    textarea.send_keys([ :control, :shift, "k" ])

    assert_equal "aaa\nccc", textarea.value
  end

  test "pasting a URL over a selection turns it into a Markdown link" do
    visit_note(create_note(content: "hello"))

    prevented = page.driver.browser.execute_script(<<~JS)
      const textarea = document.querySelector("textarea[name='note[content]']")
      textarea.focus()
      textarea.setSelectionRange(0, 5)

      const dataTransfer = new DataTransfer()
      dataTransfer.setData("text/plain", "https://example.com/note")

      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
      return event.defaultPrevented
    JS

    assert prevented
    assert_equal "[hello](https://example.com/note)", evaluate_textarea_value
  end

  test "pasting plain non-URL text over a selection is left to the browser" do
    visit_note(create_note(content: "hello"))

    prevented = page.driver.browser.execute_script(<<~JS)
      const textarea = document.querySelector("textarea[name='note[content]']")
      textarea.focus()
      textarea.setSelectionRange(0, 5)

      const dataTransfer = new DataTransfer()
      dataTransfer.setData("text/plain", "just words")

      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
      return event.defaultPrevented
    JS

    assert_not prevented
    assert_equal "hello", evaluate_textarea_value
  end

  test "shortcuts stay silent mid Japanese-IME composition" do
    visit_note(create_note)

    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("hello")

    page.execute_script(<<~JS)
      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new KeyboardEvent("keydown", { key: "b", ctrlKey: true, bubbles: true, cancelable: true, isComposing: true })
      textarea.dispatchEvent(event)
    JS

    assert_equal "hello", textarea.value
  end

  private

    def create_note(content: "")
      @folder.notes.create!(title: "Note", content: content, note_type: "md", notebook: @notebook)
    end

    def visit_note(note)
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)
    end

    def evaluate_textarea_value
      page.evaluate_script("document.querySelector(\"textarea[name='note[content]']\").value")
    end

    def selected_text
      page.evaluate_script(<<~JS)
        (() => {
          const textarea = document.querySelector("textarea[name='note[content]']")
          return textarea.value.substring(textarea.selectionStart, textarea.selectionEnd)
        })()
      JS
    end
end
