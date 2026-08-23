require "application_system_test_case"

class ListContinuationTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  # Each pair is [ starting marker text, expected continued marker on the
  # next line ] — see list_continuation_controller.js's parseListMarker.
  MARKERS = {
    "bullet dash" => [ "- ", "- " ],
    "bullet star" => [ "* ", "* " ],
    "ordered" => [ "1. ", "2. " ],
    "task list" => [ "- [ ] ", "- [ ] " ],
    "blockquote" => [ "> ", "> " ]
  }

  MARKERS.each do |name, (marker, continued)|
    test "Enter after a #{name} item continues the list with the caret right after the new marker" do
      note = create_note

      visit_note(note)
      textarea = find("textarea[name='note[content]']")
      textarea.click
      textarea.send_keys("#{marker}first")
      textarea.send_keys(:enter)
      textarea.send_keys("second")

      assert_equal "#{marker}first\n#{continued}second", textarea.value
    end

    test "Enter on an empty #{name} marker removes it instead of continuing the list" do
      note = create_note

      visit_note(note)
      textarea = find("textarea[name='note[content]']")
      textarea.click
      # The marker with nothing after it — parseListMarker leaves an
      # empty "rest", the case the removal path is for. Cleared in
      # place, not a fresh line added below.
      textarea.send_keys(marker)
      textarea.send_keys(:enter)
      textarea.send_keys("plain paragraph")

      assert_equal "plain paragraph", textarea.value
    end
  end

  test "Enter on a plain (non-list) line behaves like a normal newline" do
    note = create_note

    visit_note(note)
    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("just some text")
    textarea.send_keys(:enter)
    textarea.send_keys("more text")

    assert_equal "just some text\nmore text", textarea.value
  end

  test "list continuation preserves the native undo stack" do
    note = create_note

    visit_note(note)
    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("- first")
    textarea.send_keys(:enter)
    textarea.send_keys("second")

    assert_equal "- first\n- second", textarea.value

    # execCommand("insertText") keeps every keystroke on the browser's
    # real undo stack. A single Ctrl+Z should undo the last insertion.
    textarea.send_keys([ :control, "z" ])

    assert_not_equal "", textarea.value
    assert textarea.value.start_with?("- first\n- ")
  end

  test "pressing Enter mid Japanese-IME composition does not trigger marker continuation or removal" do
    note = create_note

    visit_note(note)
    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("- item")

    # Real IME composition can't be driven through Selenium, so this
    # proves the guard via a keydown with isComposing true. Spy on
    # document.execCommand, which both code paths call, to prove neither ran.
    page.execute_script(<<~JS)
      window.__execCommandCalls = []
      const original = document.execCommand.bind(document)
      document.execCommand = function(...args) {
        window.__execCommandCalls.push(args[0])
        return original(...args)
      }

      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true, isComposing: true })
      textarea.dispatchEvent(event)
    JS

    assert_equal [], page.evaluate_script("window.__execCommandCalls")

    # Confirms the spy itself is wired up correctly: the same key, not
    # mid-composition, does call execCommand.
    page.execute_script(<<~JS)
      const textarea = document.querySelector("textarea[name='note[content]']")
      const event = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true, isComposing: false })
      textarea.dispatchEvent(event)
    JS

    assert_equal [ "insertText" ], page.evaluate_script("window.__execCommandCalls")
  end

  private

    def create_note
      @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)
    end

    def visit_note(note)
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)
    end
end
