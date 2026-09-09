require "application_system_test_case"

class OrganizeTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
  end

  # prompt-form needs a real prompt dialog, which only a browser can
  # drive — one rename test carries that coverage for all CRUD uses.
  test "renaming a notebook from Organize stays in Organize AND updates the sidebar immediately" do
    notebook = users(:one).notebooks.create!(name: "Old Name")

    visit root_url(notebook_id: notebook.id)
    click_on "Toishi Note"

    within "#organize_notebook_#{notebook.id}" do
      accept_prompt(with: "New Name") { click_on I18n.t("home.common.rename") }
    end

    # Still in Organize (a full re-render of the same view, not left it)...
    assert_text I18n.t("home.organize.heading")
    assert_text "New Name"
    # ...and the plain sidebar (rendered alongside Organize, not replaced by
    # it) reflects the change too.
    within "#notebooks-list" do
      assert_text "New Name"
    end
  end

  # Logo/back/stale-id navigation is plain GETs plus static hrefs (see
  # HomeControllerTest). Only prompt-form wiring and drags stay here.
  test "dragging a folder above another one reorders them within the notebook, persisted across reload" do
    notebook = users(:one).notebooks.create!(name: "Organize Notebook")
    folder_a = notebook.folders.create!(name: "Folder A")
    folder_b = notebook.folders.create!(name: "Folder B")

    visit root_url(notebook_id: notebook.id, organize: true)

    drag("#organize_folder_#{folder_b.id} > div > .organize-drag-handle", above: "#organize_folder_#{folder_a.id}",
      settled: -> { folder_b.reload.position == 1 })

    assert_equal 1, folder_b.reload.position
    assert_equal 2, folder_a.reload.position

    # Reload to confirm this actually persisted server-side, not just a
    # client-side reorder that would revert on the next visit.
    visit root_url(notebook_id: notebook.id, organize: true)
    within "#organize_notebook_#{notebook.id} [data-organize-target='folderList']" do
      assert_equal [ folder_b.id, folder_a.id ], all("li[data-folder-id]", visible: :all).map { |li| li["data-folder-id"].to_i }
    end
  end

  test "dragging a folder into a different notebook reparents it and its notes, persisted across reload" do
    source_notebook = users(:one).notebooks.create!(name: "Source Notebook")
    target_notebook = users(:one).notebooks.create!(name: "Target Notebook")
    folder = source_notebook.folders.create!(name: "Movable Folder")
    note = folder.notes.create!(notebook: source_notebook, title: "Carried Note", note_type: "md")

    visit root_url(notebook_id: source_notebook.id, organize: true)

    drag("#organize_folder_#{folder.id} > div > .organize-drag-handle", into: "#organize_notebook_#{target_notebook.id} [data-organize-target='folderList']",
      settled: -> { folder.reload.notebook == target_notebook })

    assert_equal target_notebook, folder.reload.notebook
    assert_equal target_notebook, note.reload.notebook, "the folder's notes must follow via the notebook_id cascade, exactly as the non-drag move endpoint already guarantees"

    visit root_url(notebook_id: target_notebook.id, organize: true)
    within "#organize_notebook_#{target_notebook.id}" do
      assert_text "Movable Folder"
    end
  end

  test "dragging a note into a different folder persists the move, without affecting the destination folder's note order" do
    notebook = users(:one).notebooks.create!(name: "Organize Notebook")
    source_folder = notebook.folders.create!(name: "Source Folder")
    target_folder = notebook.folders.create!(name: "Target Folder")
    existing_note = target_folder.notes.create!(notebook: notebook, title: "Already Here", note_type: "md", is_pinned: true)
    moved_note = source_folder.notes.create!(notebook: notebook, title: "Moved Note", note_type: "md")

    visit root_url(notebook_id: notebook.id, organize: true)

    drag("#organize_note_#{moved_note.id} > div > .organize-drag-handle", into: "#organize_folder_#{target_folder.id} [data-organize-target='noteList']",
      settled: -> { moved_note.reload.folder == target_folder })

    assert_equal target_folder, moved_note.reload.folder
    assert_equal notebook, moved_note.notebook

    # Display order within the destination folder is still governed by
    # pin + sort — the pinned pre-existing note stays first regardless of
    # where the drop landed in the Organize tree.
    visit root_url(notebook_id: notebook.id, folder_id: target_folder.id)
    within "#notes-list" do
      titles = all("li").map(&:text)
      assert_operator titles.index { |t| t.include?("Already Here") }, :<, titles.index { |t| t.include?("Moved Note") }
    end
  end

  test "dragging a notebook above another one reorders them, persisted across reload" do
    notebook_a = users(:one).notebooks.create!(name: "Notebook A")
    notebook_b = users(:one).notebooks.create!(name: "Notebook B")

    visit root_url(notebook_id: notebook_a.id, organize: true)

    # Target the notebook's header row specifically, not its whole <li>
    # (which also has a nested folder-list Sortable container) — landing
    # on that container instead confuses which Sortable instance receives it.
    drag("#organize_notebook_#{notebook_b.id} > div > .organize-drag-handle", above: "#organize_notebook_#{notebook_a.id} > div",
      settled: -> { notebook_b.reload.position < notebook_a.reload.position })

    # Relative order, not absolute positions — a fixture notebook already
    # exists ahead of both of these.
    assert_operator notebook_b.reload.position, :<, notebook_a.reload.position
  end

  private
    # forceFallback tracks a real mouse gesture — Capybara's drag_to is
    # not enough. Mid-gesture sleeps pace mousemove events; the drop
    # polls `settled:` instead of a fixed sleep.
    def drag(source_selector, above: nil, into: nil, settled:)
      source = find(source_selector).native
      target = find(above || into).native

      action = page.driver.browser.action
      action.move_to(source).click_and_hold.perform
      sleep 0.2

      # "above" targets the row's upper edge; "into" an often-empty
      # container's center.
      offset = above ? -10 : 0
      5.times do |i|
        action.move_to(target, 0, offset - (i * 5)).perform
        sleep 0.1
      end

      action.release.perform
      wait_until("dragged order never persisted", &settled)
    end
end
