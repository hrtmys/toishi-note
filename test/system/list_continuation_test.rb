require "application_system_test_case"

class ListContinuationTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  # Full matrix in test/javascript/list_marker.test.js; the browser
  # keeps one shape per path (identical wiring otherwise).
  MARKERS = {
    "bullet dash" => [ "- ", "- " ]
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
      # The empty marker must come from a continuation, not from fresh
      # typing: type an item, continue it (arming the new empty marker),
      # then Enter again to drop out of the list.
      textarea.send_keys("#{marker}first")
      textarea.send_keys(:enter)
      textarea.send_keys(:enter)
      textarea.send_keys("plain paragraph")

      assert_equal "#{marker}first\nplain paragraph", textarea.value
    end
  end

  test "typing a fresh star marker then Enter continues the bullet instead of deleting the line" do
    note = create_note

    visit_note(note)
    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("* ")
    textarea.send_keys(:enter)
    textarea.send_keys("hello")

    assert_equal "* \n* hello", textarea.value
  end

  test "continuing an ordered item in the middle renumbers the followers" do
    note = create_note

    visit_note(note)
    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("1. first")
    textarea.send_keys(:enter)
    # The continuation already inserted "2. " — type the item text only.
    textarea.send_keys("second")
    # Back up to the end of the first line, then continue it: the new
    # "2. " item lands between, and the old "2." becomes "3.".
    textarea.send_keys(:arrow_up)
    textarea.send_keys(:enter)

    assert_equal "1. first\n2. \n3. second", textarea.value
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

  test "list continuation inserts via execCommand so the browser's native undo stack survives" do
    note = create_note

    visit_note(note)
    textarea = find("textarea[name='note[content]']")
    textarea.click
    textarea.send_keys("- first")

    # .value assignment would wipe the browser's undo stack; the
    # controller must use execCommand("insertText") instead. Chrome's undo
    # grouping changed under us, so spy the call instead of asserting undo.
    page.execute_script(<<~JS)
      window.__execCommandCalls = []
      const original = document.execCommand.bind(document)
      document.execCommand = function(...args) {
        window.__execCommandCalls.push([ args[0], args[2] ])
        return original(...args)
      }
    JS

    textarea.send_keys(:enter)
    textarea.send_keys("second")

    assert_equal "- first\n- second", textarea.value
    assert_equal [ [ "insertText", "\n- " ] ], page.evaluate_script("window.__execCommandCalls")
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
