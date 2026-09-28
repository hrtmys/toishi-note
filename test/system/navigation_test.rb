require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:one)
    @notebook = users(:one).notebooks.create!(name: "Nav Notebook")
    @folder = @notebook.folders.create!(name: "Nav Folder")
    @note_a = @folder.notes.create!(title: "Note A", note_type: "md", notebook: @notebook)
    @note_b = @folder.notes.create!(title: "Note B", note_type: "md", notebook: @notebook)
  end

  test "Turbo navigation cleans up listeners, a bare visit restores the last note, and Chrome can install the app" do
    phase "1 disconnect removes the listener connect added" do
      visit root_url(notebook_id: @notebook.id, folder_id: @folder.id, note_id: @note_a.id)
      # Installed after the first connect(); the patch survives Turbo body swaps.
      execute_script(<<~JS)
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
      within("#notes-list") { click_on @note_b.title }
      assert_selector "input[value='#{@note_b.title}']"
      within("#notes-list") { click_on @note_a.title }
      assert_selector "input[value='#{@note_a.title}']"

      assert_operator evaluate_script("window.__listenerLog.added.length"), :>, 0
      assert_operator evaluate_script("window.__listenerLog.removed.length"), :>, 0
      assert evaluate_script("window.__listenerLog.added.some((fn) => window.__listenerLog.removed.includes(fn))"),
        "removeEventListener never received the function addEventListener was given"
    end

    phase "2 a bare root visit restores the last note" do
      visit root_url
      assert_selector "input[value='#{@note_a.title}']"
    end

    # Chrome only offers "Install app" when this list is empty.
    phase "3 no installability errors" do
      errors = []
      begin
        wait_until("installability errors never cleared") do
          (errors = page.driver.browser.execute_cdp("Page.getInstallabilityErrors")["installabilityErrors"]).empty?
        end
      rescue Timeout::Error
        flunk "Chrome won't offer to install the app: #{errors.map { |e| e['errorId'] }.join(', ')}"
      end
    end
  end
end
