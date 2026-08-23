require "application_system_test_case"

class CommandPaletteTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "Ctrl+P opens the palette with the search input already focused" do
    note = create_note("Only Note")
    visit_note(note)

    press_ctrl_p

    assert_selector "#paletteModal.show"
    # The :focus match polls until true, needed because focus is set from
    # the async shown.bs.modal handler, not synchronously with "show".
    assert_selector "[data-palette-target='input']:focus"
  end

  test "Ctrl+P then Enter alternates between the two most recently viewed notes" do
    note_a = create_note("Note A")
    note_b = create_note("Note B")

    visit_note(note_a)
    visit_note(note_b)

    # note_b is open (most recently viewed); note_a is one hop back and
    # should already be selected without pressing an arrow key first.
    press_ctrl_p
    find("[data-palette-target='input']").send_keys(:enter)

    assert_current_path root_path(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note_a.id)

    # Now note_a is open, note_b is one hop back — Ctrl+P -> Enter again
    # should bounce right back to it.
    press_ctrl_p
    find("[data-palette-target='input']").send_keys(:enter)

    assert_current_path root_path(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note_b.id)
  end

  test "typing a query filters the list, and Escape closes without navigating" do
    matching = create_note("Ruby notes")
    non_matching = create_note("Something else")
    visit_note(matching)

    press_ctrl_p
    find("[data-palette-target='input']").fill_in with: "Ruby"

    within "#paletteModal" do
      assert_text matching.title
      assert_no_text non_matching.title
    end

    find("[data-palette-target='input']").send_keys(:escape)
    assert_no_selector "#paletteModal.show"
    # Never navigated away from the note that was open before Ctrl+P.
    assert_current_path root_path(notebook_id: @notebook.id, folder_id: @folder.id, note_id: matching.id)
  end

  test "ArrowDown/ArrowUp move the selection before Enter confirms it" do
    note_a = create_note("Note A", last_viewed_at: 3.days.ago)
    note_b = create_note("Note B", last_viewed_at: 2.days.ago)
    note_c = create_note("Note C", last_viewed_at: 1.day.ago)

    visit_note(note_c)

    # MRU order is C, B, A — B (index 1) starts preselected. Moving down
    # once lands on A (index 2, wrapping is not exercised here).
    press_ctrl_p
    find("[data-palette-target='input']").send_keys(:down)
    find("[data-palette-target='input']").send_keys(:enter)

    assert_current_path root_path(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note_a.id)
  end

  test "IME composition guards ArrowDown/ArrowUp/Enter from misfiring mid-conversion" do
    note = create_note("Only Note")
    visit_note(note)

    press_ctrl_p

    # Real IME composition can't be driven through Selenium; this proves
    # the guard via a keydown with isComposing true, as a browser
    # delivers for the Enter that confirms an IME conversion.
    page.execute_script(<<~JS)
      const input = document.querySelector("[data-palette-target='input']")
      const event = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true, isComposing: true })
      input.dispatchEvent(event)
    JS

    # Nothing navigated away, and the palette is still open — a
    # composing Enter must be a complete no-op.
    assert_selector "#paletteModal.show"
    assert_current_path root_path(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)
  end

  private

    def press_ctrl_p
      page.driver.browser.action.key_down(:control).send_keys("p").key_up(:control).perform
    end

    def create_note(title, last_viewed_at: nil)
      @folder.notes.create!(notebook: @notebook, title: title, note_type: "md", last_viewed_at: last_viewed_at)
    end

    def visit_note(note)
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)
    end
end
