require "application_system_test_case"

class ScrapNoteTest < ApplicationSystemTestCase
  CONTENT = "textarea[placeholder='#{I18n.t("home.scrap.content_placeholder")}']".freeze

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
    # Separate paragraphs stack vertically at any width, unlike single newlines.
    @long = @note.scrap_items.create!(content: Array.new(20) { |i| "Paragraph #{i}." }.join("\n\n"))
    @short = @note.scrap_items.create!(content: "Short fragment")
    sign_in_as users(:one)
  end

  test "scrap items render on insert, collapse by measured height, save their source, and copy all" do
    phase "1 only the long item collapses, and the toggle works" do
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)
      record_toasts
      within "#scrap_item_#{@long.id}" do
        assert_selector ".scrap-content-collapsed"
        click_on I18n.t("home.scrap.show_more")
        assert_no_selector ".scrap-content-collapsed"
        click_on I18n.t("js.scrap.show_less")
        assert_selector ".scrap-content-collapsed"
      end
      within "#scrap_item_#{@short.id}" do
        assert_no_selector ".scrap-content-collapsed"
        assert_no_button I18n.t("home.scrap.show_more")
      end
    end

    phase "2 an added item renders math and diagrams" do
      find(CONTENT).fill_in(with: <<~MD)
        # Math

        $$a^2+b^2=c^2$$

        ```mermaid
        flowchart TD
          A[Start] --> B[End]
        ```
      MD
      click_on I18n.t("home.common.add")
      within "#scrap_list_#{@note.id}" do
        assert_selector "h1", text: "Math"
        assert_selector ".katex"
        assert_selector ".mermaid svg"
      end
      assert_equal "", find(CONTENT).value
    end

    phase "3 a source tag saves on blur" do
      set_source(@short, "ChatGPT 会話")
      wait_until("scrap source never saved") { @short.reload.source == "ChatGPT 会話" }
    end

    phase "4 Copy all joins items in position order" do
      execute_script(<<~JS)
        window.__copiedText = null
        navigator.clipboard.writeText = (text) => { window.__copiedText = text; return Promise.resolve() }
      JS
      click_on I18n.t("home.scrap.copy_all")
      assert_selector ".toast.show", text: I18n.t("js.copied")
      expected = @note.scrap_items.order(:position).pluck(:content).join("\n\n---\n\n")
      assert_equal 3, @note.scrap_items.count
      assert_equal expected, evaluate_script("window.__copiedText")
    end

    phase "4b an add in flight survives a declined promote, a doubled Ctrl+Enter and an accepted delete" do
      delay_fetch(500)
      find(CONTENT).fill_in(with: "Pending scrap")
      click_on I18n.t("home.common.add")
      find(CONTENT).send_keys([ :control, :enter ])
      find(CONTENT).send_keys([ :control, :enter ])
      dismiss_confirm(I18n.t("home.scrap.promote_confirm")) { promote_button(@short).click }
      accept_confirm(I18n.t("home.scrap.delete_confirm")) { delete_button(@long).click }
      restore_fetch

      within("#scrap_list_#{@note.id}") { assert_text "Pending scrap" }
      assert_no_selector "#scrap_item_#{@long.id}"
      assert_equal "", find(CONTENT).value
      wait_until("the delete never saved") { !ScrapItem.exists?(@long.id) }
      assert ScrapItem.exists?(@short.id)
      assert_equal 1, @note.scrap_items.where(content: "Pending scrap").count
      assert_no_toast I18n.t("js.forms.add_failed")
      assert_no_toast I18n.t("js.forms.save_failed")
    end

    phase "5 failed source and add saves toast and keep input" do
      force_fetch_rejection
      set_source(@short, "Claude")
      assert_toast I18n.t("js.scrap.source_save_failed")
      find(CONTENT).fill_in(with: "From a chat")
      click_on I18n.t("home.common.add")
      assert_toast I18n.t("js.forms.add_failed")
      assert_equal "From a chat", find(CONTENT).value
      assert_no_toast I18n.t("js.forms.save_failed")

      accept_confirm(I18n.t("home.scrap.delete_confirm")) { delete_button(@short).click }
      assert_toast I18n.t("js.forms.save_failed")
      assert_selector "#scrap_item_#{@short.id}"
      assert ScrapItem.exists?(@short.id)
      restore_fetch
    end

    phase "6 promote opens the new note" do
      accept_confirm(I18n.t("home.scrap.promote_confirm")) { promote_button(@short).click }
      wait_until("promote never created the note") { @folder.notes.where(note_type: "md").exists? }
      promoted = @folder.notes.find_by!(note_type: "md")
      assert_current_path(/note_id=#{promoted.id}/)
      assert_field with: "Short fragment"
      assert_not ScrapItem.exists?(@short.id)
      assert_equal 1, @folder.notes.where(note_type: "md").count
    end
  end

  private

    def promote_button(item)
      row = find("#scrap_item_#{item.id}")
      row.hover
      row.find("button[title='#{I18n.t("home.scrap.promote_title")}']")
    end

    def delete_button(item)
      row = find("#scrap_item_#{item.id}")
      row.hover
      row.find("button", text: "×")
    end

    def set_source(item, value)
      row = find("#scrap_item_#{item.id}")
      row.hover
      row.fill_in "source", with: value
      row.find_field("source").native.send_keys(:tab) # blur fires change
    end
end
