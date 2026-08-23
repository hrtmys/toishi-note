require "application_system_test_case"

class SidebarScrollTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")

    # Enough notes to overflow the notes-list's fixed height, so the
    # active row starts off-screen. Default sort is "Updated" desc, so
    # @notes.last (oldest) genuinely lands at the bottom of the list.
    @notes = Array.new(50) { |i| @folder.notes.create!(notebook: @notebook, title: "Note #{i}", note_type: "md", updated_at: i.days.ago) }
  end

  test "opening a note far down the list scrolls it into view" do
    last_note = @notes.last

    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: last_note.id)

    within "#notes-list" do
      assert_selector ".bg-secondary", text: last_note.title
    end

    assert row_visible_within_container?("#notes-list", active_row_id(last_note))
  end

  test "deleting the currently-open note preserves the list's previous scroll position" do
    target_note = @notes.last
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: target_note.id)

    # Scroll further than opening the note alone would land, so the
    # restored value can only be the saved position, not scrollIntoView.
    page.execute_script(<<~JS)
      const list = document.querySelector("#notes-list")
      list.scrollTop = list.scrollHeight
      list.dispatchEvent(new Event("scroll"))
    JS
    scrolled_to = Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        value = page.evaluate_script("document.querySelector('#notes-list').scrollTop")
        break value if value.to_i.positive?
        sleep 0.05
      end
    end

    # Deleted via the note editor header's delete button, which needs
    # turbo_frame: "_top" to reach the sidebar with its redirect — without
    # it, the sidebar would never find out the note is gone.
    find("#note_editor_header").hover
    within "#note_editor_header" do
      accept_confirm { click_on I18n.t("home.common.delete") }
    end

    # NotesController#destroy redirects with no note_id — no active row —
    # exactly the case that has to fall back to the saved position.
    assert_no_selector "#notes-list .bg-secondary"

    # The list is one row shorter after delete, so max scrollTop shrank
    # too — the browser clamps scrolled_to down. Assert against that
    # clamped ceiling, not the now-unreachable pre-delete number.
    max_scroll_top = page.evaluate_script(<<~JS).to_i
      document.querySelector('#notes-list').scrollHeight - document.querySelector('#notes-list').clientHeight
    JS
    assert_equal [ scrolled_to, max_scroll_top ].min, page.evaluate_script("document.querySelector('#notes-list').scrollTop").to_i
  end

  private

  def active_row_id(note)
    "note_#{note.id}_title"
  end

  # Confirms the active row's bounding box falls inside the scrollable
  # container's viewport — a direct DOM check, not a scrollTop inference.
  def row_visible_within_container?(container_selector, active_title_id)
    page.evaluate_script(<<~JS)
      (function() {
        const container = document.querySelector(#{container_selector.to_json})
        const activeRow = document.querySelector(#{"##{active_title_id}".to_json}).closest("li")
        const containerRect = container.getBoundingClientRect()
        const rowRect = activeRow.getBoundingClientRect()
        return rowRect.top >= containerRect.top && rowRect.bottom <= containerRect.bottom
      })()
    JS
  end
end
