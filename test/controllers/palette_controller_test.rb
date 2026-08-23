require "test_helper"

class PaletteControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Notebook")
    @folder = @notebook.folders.create!(name: "Folder")
  end

  test "a blank query returns the 10 most recently viewed notes, most recent first" do
    old_note = create_note("Old", last_viewed_at: 2.days.ago)
    recent_note = create_note("Recent", last_viewed_at: 1.hour.ago)

    get palette_url

    assert_response :success
    positions = [ recent_note, old_note ].map { |note| response.body.index(note.title) }
    assert_equal positions.sort, positions
  end

  test "a blank/whitespace-only query is treated the same as no query at all" do
    note = create_note("Only Note", last_viewed_at: 1.hour.ago)

    get palette_url, params: { q: "   " }

    assert_response :success
    assert_match note.title, response.body
  end

  test "a search ranks an exact-prefix match above a match elsewhere in the title" do
    contains_match = create_note("Meeting notes about Ruby", last_viewed_at: 2.days.ago)
    prefix_match = create_note("Ruby study log", last_viewed_at: 3.days.ago)

    get palette_url, params: { q: "Ruby" }

    assert_response :success
    prefix_position = response.body.index(prefix_match.title)
    contains_position = response.body.index(contains_match.title)
    assert prefix_position < contains_position
  end

  test "a search excludes notes that don't match at all" do
    matching = create_note("Ruby notes")
    non_matching = create_note("Something else entirely")

    get palette_url, params: { q: "Ruby" }

    assert_response :success
    assert_match matching.title, response.body
    assert_no_match non_matching.title, response.body
  end

  test "each result shows its notebook and folder for disambiguation" do
    create_note("Note")

    get palette_url

    assert_response :success
    assert_match @notebook.name, response.body
    assert_match @folder.name, response.body
  end

  private

    def create_note(title, last_viewed_at: nil)
      @folder.notes.create!(notebook: @notebook, title: title, note_type: "md", last_viewed_at: last_viewed_at)
    end
end
