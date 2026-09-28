require "application_system_test_case"

class SidebarScrollTest < ApplicationSystemTestCase
  LIST = "#notes-list".freeze

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    # Enough rows to overflow the list; newest-updated first puts the oldest at the bottom.
    @notes = Array.new(50) { |i| @folder.notes.create!(notebook: @notebook, title: "Note #{i}", note_type: "md", updated_at: i.days.ago) }
  end

  test "the notes list keeps the active row and scroll position in view and sorts and pins client-side" do
    oldest = @notes.last

    phase "1 the active row is scrolled into view" do
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: oldest.id)
      within(LIST) { assert_selector ".bg-secondary", text: oldest.title }
      assert active_row_visible?(oldest), "the active row is outside the list viewport"
    end

    phase "2 deleting the open note restores the saved scroll position" do
      # Scroll past where scrollIntoView lands, so only the saved position can explain the result.
      execute_script(<<~JS)
        const list = document.querySelector("#{LIST}")
        list.scrollTop = list.scrollHeight
        list.dispatchEvent(new Event("scroll"))
      JS
      wait_until("the notes list never scrolled") { scroll_top.positive? }
      saved = scroll_top

      find("#note_editor_header").hover
      within("#note_editor_header") { accept_confirm { click_on I18n.t("home.common.delete") } }
      assert_no_selector "#{LIST} .bg-secondary"

      max = evaluate_script("(l => l.scrollHeight - l.clientHeight)(document.querySelector('#{LIST}'))").to_i
      # Offsets round per devicePixelRatio, so allow 2px.
      assert_in_delta [ saved, max ].min, scroll_top, 2
    end

    phase "3 A-Z sorts by title and flips on a second click" do
      titles = @notes[0..-2].map(&:title)
      click_on "A-Z"
      assert_equal titles.sort, note_titles
      click_on "A-Z"
      assert_equal titles.sort.reverse, note_titles
    end

    phase "4 a pinned note stays first across sort modes" do
      row = find("#note_#{@notes[5].id}_title").ancestor("li")
      row.hover
      row.find(".hover-target-icon[title='#{I18n.t("home.notes.pin")}']").click
      wait_until("the pinned note never moved to the top") { note_titles.first == "Note 5" }
      wait_until("pin PATCH never landed") { @notes[5].reload.is_pinned? }
      click_on "A-Z"
      assert_equal "Note 5", note_titles.first
    end
  end

  private

    def scroll_top
      evaluate_script("document.querySelector('#{LIST}').scrollTop").to_i
    end

    def note_titles
      all("#{LIST} li span[id^='note_']").map(&:text)
    end

    def active_row_visible?(note)
      evaluate_script(<<~JS)
        (() => {
          const list = document.querySelector("#{LIST}").getBoundingClientRect()
          const row = document.querySelector("#note_#{note.id}_title").closest("li").getBoundingClientRect()
          return row.top >= list.top && row.bottom <= list.bottom
        })()
      JS
    end
end
