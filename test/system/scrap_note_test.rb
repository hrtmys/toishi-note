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

    phase "5 failed source and add saves toast and keep input" do
      force_fetch_rejection
      set_source(@short, "Claude")
      assert_toast I18n.t("js.scrap.source_save_failed")
      find(CONTENT).fill_in(with: "From a chat")
      click_on I18n.t("home.common.add")
      assert_toast I18n.t("js.forms.add_failed")
      assert_equal "From a chat", find(CONTENT).value
    end
  end

  private

    def set_source(item, value)
      row = find("#scrap_item_#{item.id}")
      row.hover
      row.fill_in "source", with: value
      row.find_field("source").native.send_keys(:tab) # blur fires change
    end
end
