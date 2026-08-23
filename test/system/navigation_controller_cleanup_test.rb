require "application_system_test_case"

# Regression coverage: navigation_controller.js#disconnect used to
# re-bind a fresh function instead of reusing the one passed to
# addEventListener, so removeEventListener was silently a no-op.
class NavigationControllerCleanupTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)

    @notebook = users(:one).notebooks.create!(name: "Nav Notebook")
    @folder = @notebook.folders.create!(name: "Nav Folder")
    @note_a = @folder.notes.create!(title: "Note A", note_type: "md", notebook: @notebook)
    @note_b = @folder.notes.create!(title: "Note B", note_type: "md", notebook: @notebook)
  end

  test "disconnect removes the exact click listener connect() added, not a mismatched one" do
    visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note_a.id)

    # Installed after the first connect() ran uninstrumented — this
    # monkeypatch survives Turbo body replacement.
    page.execute_script(<<~JS)
      window.__listenerLog = { added: [], removed: [] }
      const origAdd = EventTarget.prototype.addEventListener
      const origRemove = EventTarget.prototype.removeEventListener
      EventTarget.prototype.addEventListener = function(type, handler, options) {
        if (type === "click" && this.tagName === "BODY") window.__listenerLog.added.push(handler)
        return origAdd.call(this, type, handler, options)
      }
      EventTarget.prototype.removeEventListener = function(type, handler, options) {
        if (type === "click" && this.tagName === "BODY") window.__listenerLog.removed.push(handler)
        return origRemove.call(this, type, handler, options)
      }
    JS

    # Two real Turbo Drive navigations, not Capybara#visit, which
    # destroys the JS realm. Every disconnect() must remove the same
    # function reference its own connect() added.
    within "#notes-list" do
      click_on @note_b.title
    end
    assert_selector "input[value='#{@note_b.title}']"

    within "#notes-list" do
      click_on @note_a.title
    end
    assert_selector "input[value='#{@note_a.title}']"

    added_count = page.evaluate_script("window.__listenerLog.added.length")
    removed_count = page.evaluate_script("window.__listenerLog.removed.length")
    assert_operator added_count, :>, 0, "expected at least one new body click listener after the spy was installed"
    assert_operator removed_count, :>, 0, "expected at least one disconnect() to have called removeEventListener by this point"

    matched = page.evaluate_script(<<~JS)
      window.__listenerLog.added.some((fn) => window.__listenerLog.removed.includes(fn))
    JS
    assert matched, "removeEventListener must be called with the exact function reference addEventListener received for that same instance"
  end
end
