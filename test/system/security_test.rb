require "application_system_test_case"

# End-to-end proof that user-typed content can't execute as script, and
# that the CSP header is present. Tests behavior, not implementation:
# "did the payload actually fire", not "was DOMPurify.sanitize called".
class SecurityTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  # <script> tags never execute via innerHTML (browser platform behavior),
  # so this uses an <img onerror> instead — fires as soon as it's
  # inserted if content was rendered unsanitized.
  XSS_PAYLOAD = %(<img src="x" onerror="window.__xss_fired = true">).freeze

  test "a scrap item's content can't execute script when rendered" do
    note = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
    note.scrap_items.create!(content: XSS_PAYLOAD)

    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    assert_no_selector "img[onerror]"
    assert_nil page.evaluate_script("window.__xss_fired")
  end

  test "a note's live preview pane can't execute script when rendered" do
    note = @folder.notes.create!(title: "MD Note", note_type: "md", content: "", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    fill_in "note[content]", with: XSS_PAYLOAD

    assert_no_selector ".markdown-content img[onerror]"
    assert_nil page.evaluate_script("window.__xss_fired")
  end

  test "an existing note's saved content can't execute script on reload" do
    # Covers the render-from-persisted-content path, not just live-typing
    # above — a note reopened after being saved elsewhere is the more
    # realistic case for untrusted content.
    note = @folder.notes.create!(title: "MD Note", note_type: "md", content: XSS_PAYLOAD, notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    assert_no_selector ".markdown-content img[onerror]"
    assert_nil page.evaluate_script("window.__xss_fired")
  end

  test "the Content-Security-Policy header is present and blocks inline script" do
    note = @folder.notes.create!(title: "MD Note", note_type: "md", content: "", notebook: @notebook)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)

    # Proof the header does something, not just that it's present: inject
    # a real <script> at runtime and confirm CSP refuses to run it.
    page.execute_script(<<~JS)
      window.__csp_script_ran = false
      const script = document.createElement("script")
      script.textContent = "window.__csp_script_ran = true"
      document.body.appendChild(script)
    JS

    assert_equal false, page.evaluate_script("window.__csp_script_ran")
  end
end
