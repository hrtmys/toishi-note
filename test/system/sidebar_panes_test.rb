require "application_system_test_case"

class SidebarPanesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    40.times { |i| @user.notebooks.create!(name: "Notebook #{i}") }
    @notebook = @user.notebooks.create!(name: "Busy Notebook")
    40.times { |i| @notebook.folders.create!(name: "Folder #{i}") }
  end

  teardown { page.driver.browser.manage.window.resize_to(1400, 1400) }

  test "long notebook and folder lists grow to their share of the sidebar, then scroll" do
    open_busy_notebook

    wrapper = sidebar_height
    %w[notebooks folders].each do |pane|
      height = pane_height(pane)
      assert_operator height, :>=, wrapper * 0.33, "#{pane} pane stopped short of its cap"
      assert_operator height, :<=, wrapper * 0.35 + 2, "#{pane} pane grew past its cap"
      assert list_scrolls?("##{pane}-list"), "#{pane} list should scroll inside its pane"
    end
  end

  test "on a short window the capped panes shrink first and Files keeps a usable height" do
    page.driver.browser.manage.window.resize_to(1400, 600)
    open_busy_notebook

    assert_operator pane_height("files"), :>=, 160
    assert_operator pane_height("notebooks"), :>=, 63
    assert_operator pane_height("folders"), :>=, 63
  end

  test "when even the minimums don't fit, the sidebar itself scrolls" do
    page.driver.browser.manage.window.resize_to(1400, 380)
    open_busy_notebook

    assert list_scrolls?("#sidebarMenu > div"), "the sidebar wrapper should scroll"
    assert_operator pane_height("files"), :>=, 160
  end

  private

    def open_busy_notebook
      sign_in_as(@user)
      visit root_url(notebook_id: @notebook.id)
      assert_selector "#folders-list li", count: 40
    end

    def pane_height(name)
      height = page.evaluate_script(<<~JS)
        (() => {
          const pane = document.querySelector('[data-sidebar-pane="#{name}"]')
          return pane ? pane.getBoundingClientRect().height : null
        })()
      JS
      assert height, "no [data-sidebar-pane=#{name}] element"
      height
    end

    def sidebar_height
      page.evaluate_script("document.querySelector('#sidebarMenu > div').clientHeight")
    end

    def list_scrolls?(selector)
      page.evaluate_script("(el => el.scrollHeight > el.clientHeight)(document.querySelector('#{selector}'))")
    end
end
