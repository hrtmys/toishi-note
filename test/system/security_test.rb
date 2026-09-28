require "application_system_test_case"

# Behavior, not implementation: "did the payload run", not "was DOMPurify called".
class SecurityTest < ApplicationSystemTestCase
  # <script> never executes via innerHTML, so an <img onerror> is the probe.
  XSS_PAYLOAD = %(<img src="x" onerror="window.__xss_fired = true">).freeze
  JAVASCRIPT_LINK = "[click](javascript:window.__xss_fired=true)".freeze
  MERMAID_LABEL = <<~MD.freeze
    ```mermaid
    flowchart TD
      A["<img src=x onerror=window.__xss_fired=true>"] --> B
    ```
  MD
  KATEX_HREF = "$\\href{javascript:window.__xss_fired=true}{x}$".freeze

  setup do
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Test Notebook")
    @folder = @notebook.folders.create!(name: "Test Folder")
  end

  test "untrusted content never executes, and CSP blocks injected inline script" do
    phase "1 persisted scrap item" do
      scrap = @folder.notes.create!(title: "Scrap Note", note_type: "scrap", notebook: @notebook)
      scrap.scrap_items.create!(content: XSS_PAYLOAD)
      visit_note scrap
      # The sanitized <img> itself proves the item was rendered.
      assert_selector "#scrap_list_#{scrap.id} img", visible: :all
      assert_no_selector "img[onerror]", visible: :all
      assert_not_fired
    end

    note = @folder.notes.create!(title: "MD Note", note_type: "md", notebook: @notebook,
      content: [ XSS_PAYLOAD, JAVASCRIPT_LINK ].join("\n\n"))

    phase "2 persisted md note" do
      visit_note note
      assert_selector ".markdown-content a", text: "click"
      assert_selector ".markdown-content img", visible: :all
      assert_no_selector ".markdown-content img[onerror]", visible: :all
      assert_no_selector "a[href^='javascript:']"
      assert_not_fired
    end

    phase "3 live preview" do
      fill_in "note[content]", with: [ XSS_PAYLOAD, JAVASCRIPT_LINK, MERMAID_LABEL, KATEX_HREF ].join("\n\n")
      assert_selector ".markdown-content .mermaid svg"
      assert_selector ".markdown-content .katex"
      assert_no_selector ".markdown-content img[onerror]", visible: :all
      assert_no_selector ".markdown-content a[href^='javascript:']", visible: :all
      assert_not_fired
    end

    phase "4 CSP blocks inline script" do
      execute_script(<<~JS)
        window.__csp_script_ran = false
        const script = document.createElement("script")
        script.textContent = "window.__csp_script_ran = true"
        document.body.appendChild(script)
      JS
      assert_equal false, evaluate_script("window.__csp_script_ran")
    end
  end

  private

  def visit_note(note)
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: note.id)
  end

  def assert_not_fired
    assert_nil evaluate_script("window.__xss_fired"), "an XSS payload executed"
  end
end
