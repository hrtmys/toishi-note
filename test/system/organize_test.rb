require "application_system_test_case"

class OrganizeTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    user = users(:one)
    @old = user.notebooks.create!(name: "Old Name")
    source = user.notebooks.create!(name: "Source Notebook")
    @movable_folder = source.folders.create!(name: "Movable Folder")
    @carried_note = @movable_folder.notes.create!(notebook: source, title: "Carried Note", note_type: "md")
    @target = user.notebooks.create!(name: "Target Notebook")
    @target_folder = @target.folders.create!(name: "Target Folder")
    @target_folder.notes.create!(notebook: @target, title: "Already Here", note_type: "md", is_pinned: true)
    holding = @target.folders.create!(name: "Holding Folder")
    @moved_note = holding.notes.create!(notebook: @target, title: "Moved Note", note_type: "md")
    @notebook_a = user.notebooks.create!(name: "Notebook A")
    @notebook_b = user.notebooks.create!(name: "Notebook B")
    sign_in_as user
  end

  test "Organize renames through a prompt and persists real drags of notebooks, folders and notes" do
    phase "1 rename through prompt()" do
      visit root_url(notebook_id: @old.id, organize: true)
      record_toasts
      within "#organize_notebook_#{@old.id}" do
        accept_prompt(with: "整理 ノート") { click_on I18n.t("home.common.rename") }
      end
      assert_text I18n.t("home.organize.heading")
      within("#notebooks-list") { assert_text "整理 ノート" }
      assert_selector ".toast.show", text: I18n.t("home.notebooks.flash.renamed")
      assert_equal "整理 ノート", @old.reload.name
    end

    # The drags run after the rename's re-render, so Sortable must have re-bound.
    phase "2 folder into another notebook" do
      drag("#organize_folder_#{@movable_folder.id} > div > .organize-drag-handle",
        into: "#organize_notebook_#{@target.id} [data-organize-target='folderList']",
        settled: -> { @movable_folder.reload.notebook == @target })
      wait_until("the folder's notes never followed it") { @carried_note.reload.notebook == @target }
    end

    phase "3 note into another folder" do
      drag("#organize_note_#{@moved_note.id} > div > .organize-drag-handle",
        into: "#organize_folder_#{@target_folder.id} [data-organize-target='noteList']",
        settled: -> { @moved_note.reload.folder == @target_folder })
    end

    phase "4 notebook reorder" do
      # The header row, not the whole <li>: that also holds the nested folder Sortable.
      drag("#organize_notebook_#{@notebook_b.id} > div > .organize-drag-handle", above: "#organize_notebook_#{@notebook_a.id} > div",
        settled: -> { @notebook_b.reload.position < @notebook_a.reload.position })
    end
  end

  private
    # forceFallback tracks a real mouse gesture, which Capybara's drag_to
    # doesn't produce. Mid-gesture sleeps pace the mousemove events.
    def drag(source_selector, above: nil, into: nil, settled:)
      source = find(source_selector)
      target = find(above || into)
      source.scroll_to(source, align: :center)

      action = page.driver.browser.action
      action.move_to(source.native).click_and_hold.perform
      sleep 0.2

      offset = above ? -10 : 0
      5.times do |i|
        action.move_to(target.native, 0, offset - (i * 5)).perform
        sleep 0.1
      end

      action.release.perform
      wait_until("dragged order never persisted", &settled)
    end
end
