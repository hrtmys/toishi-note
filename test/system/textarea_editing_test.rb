require "application_system_test_case"

class TextareaEditingTest < ApplicationSystemTestCase
  TEXTAREA = "textarea[name='note[content]']".freeze

  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)
  end

  test "the md textarea handles real shortcuts, URL paste and list continuation, and holds autosave during IME composition" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
    textarea = find(TEXTAREA)

    phase "1 IME holds autosave on both fields" do
      execute_script(<<~JS)
        window.__noteSaves = 0
        const realFetch = window.fetch.bind(window)
        window.fetch = (url, ...rest) => {
          if (String(url).includes("/notes/")) window.__noteSaves += 1
          return realFetch(url, ...rest)
        }
        for (const field of [document.querySelector("#{TEXTAREA}"), document.querySelector("#note_title_input")]) {
          // A plain keystroke just before the composition leaves a debounced save pending.
          field.value = "k"
          field.dispatchEvent(new InputEvent("input", { bubbles: true }))
          field.dispatchEvent(new CompositionEvent("compositionstart", { bubbles: true }))
          field.value = "か"
          field.dispatchEvent(new InputEvent("input", { bubbles: true, isComposing: true }))
        }
      JS
      sleep 0.7 # outlasts the 500ms autosave debounce
      assert_equal 0, evaluate_script("window.__noteSaves"), "a save ran mid-composition"
      # One field at a time: two saves in flight on one lock_version conflict by design.
      execute_script("document.querySelector(\"#{TEXTAREA}\").dispatchEvent(new CompositionEvent(\"compositionend\", { bubbles: true }))")
      wait_until("the confirmed content never saved") { @note.reload.content == "か" }
      execute_script("document.querySelector(\"#note_title_input\").dispatchEvent(new CompositionEvent(\"compositionend\", { bubbles: true }))")
      wait_until("the confirmed title never saved") { @note.reload.title == "か" }
      assert_equal 2, evaluate_script("window.__noteSaves")
    end

    phase "2 Ctrl+B" do
      clear(textarea)
      textarea.send_keys("hello", [ :control, "a" ], [ :control, "b" ])
      assert_equal "**hello**", textarea.value
    end

    phase "3 Ctrl+K" do
      clear(textarea)
      textarea.send_keys("hello", [ :control, "a" ], [ :control, "k" ])
      assert_equal "[hello](url)", textarea.value
      assert_equal "url", selected_text
    end

    phase "4 URL paste" do
      clear(textarea)
      textarea.send_keys("hello")
      assert paste_text("https://example.com/note", select: [ 0, 5 ]), "a URL over a selection was not handled"
      assert_equal "[hello](https://example.com/note)", textarea.value
      assert_not paste_text("javascript:alert(1)", select: "all"), "a javascript: URL was turned into a link"
      assert_equal "[hello](https://example.com/note)", textarea.value
      assert_not paste_text("just words", select: "all"), "plain words were intercepted"
    end

    phase "5 list continuation" do
      clear(textarea)
      textarea.send_keys("- first")
      spy_exec_command
      textarea.send_keys(:enter)
      assert_equal [ "insertText", "\n- " ], evaluate_script("window.__execCommandCalls[0]")
      textarea.send_keys("second", :enter, :enter, "plain")
      assert_equal "- first\n- second\nplain", textarea.value
    end
  end

  private

  def clear(textarea)
    textarea.send_keys([ :control, "a" ], :backspace)
    assert_equal "", textarea.value
  end

  # A synthetic paste never inserts on its own, so the handler's
  # preventDefault is the observable signal.
  def paste_text(text, select:)
    page.driver.browser.execute_script(<<~JS, text, select)
      const [text, select] = arguments
      const textarea = document.querySelector("#{TEXTAREA}")
      textarea.focus()
      if (select === "all") textarea.select()
      else textarea.setSelectionRange(select[0], select[1])
      const dataTransfer = new DataTransfer()
      dataTransfer.setData("text/plain", text)
      const event = new ClipboardEvent("paste", { bubbles: true, cancelable: true, clipboardData: dataTransfer })
      textarea.dispatchEvent(event)
      return event.defaultPrevented
    JS
  end

  def selected_text
    evaluate_script(<<~JS)
      (() => {
        const textarea = document.querySelector("#{TEXTAREA}")
        return textarea.value.substring(textarea.selectionStart, textarea.selectionEnd)
      })()
    JS
  end
end
