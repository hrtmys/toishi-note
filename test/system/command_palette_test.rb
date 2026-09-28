require "application_system_test_case"

class CommandPaletteTest < ApplicationSystemTestCase
  INPUT = "[data-palette-target='input']".freeze
  SELECTED = "#palette-listbox li[role='option'][aria-selected='true']".freeze

  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note_a = create_note("Note A", last_viewed_at: 3.days.ago)
    @note_b = create_note("Note B", last_viewed_at: 2.days.ago)
    @note_c = create_note("Note C", last_viewed_at: 1.day.ago)
  end

  test "Ctrl+P palette opens focused, filters, moves and visits by keyboard" do
    visit path_for(@note_c)

    phase "1 Escape inside the opening fade still closes" do
      # No wait on purpose, so the Escape lands during Bootstrap's show transition.
      press_ctrl_p
      find(INPUT).send_keys(:escape)
      assert_no_selector "#paletteModal.show"
      # Fully hidden, so the next Ctrl+P isn't swallowed by the closing fade.
      assert_no_selector "#paletteModal", visible: true
      assert_current_path path_for(@note_c)
    end

    phase "2 opens focused with the previous note preselected" do
      press_ctrl_p
      assert_selector "#paletteModal.show"
      assert_selector "#{INPUT}:focus"
      assert_selector SELECTED, text: @note_b.title
      assert_selector SELECTED, count: 1
    end

    phase "3 ArrowDown moves the single selection" do
      find(INPUT).send_keys(:down)
      assert_selector SELECTED, text: @note_a.title
      assert_selector SELECTED, count: 1
    end

    phase "4 filtering marks the frame busy until results land" do
      delay_fetch(300)
      find(INPUT).send_keys("Note A")
      assert_selector "turbo-frame#palette_results[aria-busy='true']"
      assert_no_selector "turbo-frame#palette_results[aria-busy]"
      within "#palette-listbox" do
        assert_text @note_a.title
        assert_no_text @note_b.title
        assert_no_text @note_c.title
      end
    end

    phase "5 Enter visits the selection" do
      find(INPUT).send_keys(:enter)
      assert_current_path path_for(@note_a)
    end
  end

  private

    def press_ctrl_p
      page.driver.browser.action.key_down(:control).send_keys("p").key_up(:control).perform
    end

    def create_note(title, last_viewed_at:)
      @folder.notes.create!(notebook: @notebook, title: title, note_type: "md", last_viewed_at: last_viewed_at)
    end

    def path_for(note)
      root_path(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)
    end
end
