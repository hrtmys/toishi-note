require "application_system_test_case"

class ScrapImprovementsTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
    @note = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
  end

  test "promoting a scrap item creates an independent md note and removes it from the scrap list" do
    item = @note.scrap_items.create!(content: "A useful fragment")
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    row = find("#scrap_item_#{item.id}")
    row.hover
    accept_confirm { row.find("[title='#{I18n.t("home.scrap.promote_title")}']").click }

    # Navigated to a brand-new md note carrying the scrap's content over.
    assert_selector "textarea[name='note[content]']", text: "A useful fragment"
    assert_not ScrapItem.exists?(item.id)
  end

  test "Copy all concatenates every scrap item, separated by ---, and shows a toast" do
    @note.scrap_items.create!(content: "First fragment")
    @note.scrap_items.create!(content: "Second fragment")

    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    # Spies on the clipboard call rather than reading it back, which
    # needs a "clipboard-read" grant this headless setup doesn't have.
    page.execute_script(<<~JS)
      window.__copiedText = null
      navigator.clipboard.writeText = (text) => { window.__copiedText = text; return Promise.resolve() }
    JS

    click_on I18n.t("home.scrap.copy_all")

    assert_selector ".toast.show", text: I18n.t("js.copied")
    assert_equal "First fragment\n\n---\n\nSecond fragment", page.evaluate_script("window.__copiedText")
  end

  test "setting an optional source tag on a scrap item persists it" do
    item = @note.scrap_items.create!(content: "From a chat")
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    row = find("#scrap_item_#{item.id}")
    row.hover
    row.fill_in "source", with: "ChatGPT conversation"
    row.find_field("source").native.send_keys(:tab) # blur to trigger the change event

    # The save is a background fetch — give it a moment to land.
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.1 until item.reload.source.present? }
    assert_equal "ChatGPT conversation", item.source
  end

  test "long scrap content collapses, with a working Show more/less toggle" do
    # Separate paragraphs, so they reliably stack vertically regardless of
    # container width — unlike single newlines, which Markdown collapses
    # into one wrapping line.
    long_content = Array.new(20) { |i| "Paragraph #{i}." }.join("\n\n")
    item = @note.scrap_items.create!(content: long_content)

    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note.id)

    within "#scrap_item_#{item.id}" do
      assert_selector ".scrap-content-collapsed"
      click_on I18n.t("home.scrap.show_more")
      assert_no_selector ".scrap-content-collapsed"
      click_on I18n.t("js.scrap.show_less")
      assert_selector ".scrap-content-collapsed"
    end
  end
end
