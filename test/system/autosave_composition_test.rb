require "application_system_test_case"

class AutosaveCompositionTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "typing mid IME composition does not autosave; the confirmed text does" do
    note = @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)

    visit_note(note)
    textarea = find("textarea[name='note[content]']")
    textarea.click

    # Spy on fetch, which autosave_controller.js calls after its 500ms
    # debounce — no fetch means no save happened.
    page.execute_script(<<~JS)
      window.__fetchCalls = []
      const originalFetch = window.fetch.bind(window)
      window.fetch = function(...args) {
        window.__fetchCalls.push(args[0])
        return originalFetch(...args)
      }
    JS

    # An unconfirmed IME keystroke: compositionstart, then an input event
    # flagged isComposing, as Chrome delivers mid-conversion.
    page.execute_script(<<~JS)
      const textarea = document.querySelector("textarea[name='note[content]']")
      textarea.dispatchEvent(new CompositionEvent("compositionstart", { bubbles: true }))
      textarea.value = "か"
      textarea.dispatchEvent(new InputEvent("input", { bubbles: true, isComposing: true }))
    JS

    sleep 1 # longer than the 500ms autosave debounce
    assert_equal [], page.evaluate_script("window.__fetchCalls")

    # Confirming the conversion ends composition, which re-triggers the save.
    page.execute_script(<<~JS)
      const textarea = document.querySelector("textarea[name='note[content]']")
      textarea.dispatchEvent(new CompositionEvent("compositionend", { bubbles: true }))
    JS

    sleep 1.5 # debounce plus the request round trip
    assert_equal 1, page.evaluate_script("window.__fetchCalls.length")
  end

  test "the title input likewise holds its save until composition is confirmed" do
    note = @folder.notes.create!(title: "Note", content: "", note_type: "md", notebook: @notebook)

    visit_note(note)
    title_input = find("#note_title_input")
    title_input.click

    page.execute_script(<<~JS)
      window.__fetchCalls = []
      const originalFetch = window.fetch.bind(window)
      window.fetch = function(...args) {
        window.__fetchCalls.push(args[0])
        return originalFetch(...args)
      }
    JS

    page.execute_script(<<~JS)
      const input = document.querySelector("#note_title_input")
      input.dispatchEvent(new CompositionEvent("compositionstart", { bubbles: true }))
      input.value = "か"
      input.dispatchEvent(new InputEvent("input", { bubbles: true, isComposing: true }))
    JS

    sleep 1 # longer than the 500ms autosave debounce
    assert_equal [], page.evaluate_script("window.__fetchCalls")

    page.execute_script(<<~JS)
      const input = document.querySelector("#note_title_input")
      input.dispatchEvent(new CompositionEvent("compositionend", { bubbles: true }))
    JS

    sleep 1.5 # debounce plus the request round trip
    assert_equal 1, page.evaluate_script("window.__fetchCalls.length")
  end

  private

    def visit_note(note)
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)
    end
end
