require "application_system_test_case"

class SidebarPanesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    40.times { |i| @user.notebooks.create!(name: "Notebook #{i}") }
    @notebook = @user.notebooks.create!(name: "Busy Notebook")
    40.times { |i| @notebook.folders.create!(name: "Folder #{i}") }
  end

  test "sidebar panes cap, shrink and scroll across window heights" do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as(@user)
    visit root_url(notebook_id: @notebook.id)
    assert_selector "#folders-list li", count: 40

    phase "1 tall window: long lists fill their capped share, then scroll" do
      wrapper = evaluate_script("document.querySelector('#sidebarMenu > div').clientHeight")
      %w[notebooks folders].each do |pane|
        height = pane_height(pane)
        assert_operator height, :>=, wrapper * 0.33, "#{pane} pane stopped short of its cap"
        assert_operator height, :<=, wrapper * 0.35 + 2, "#{pane} pane grew past its cap"
        assert scrolls?("##{pane}-list"), "#{pane} list should scroll inside its pane"
      end
    end

    phase "2 short window: capped panes shrink first, Files keeps a usable height" do
      resize_height(600)
      assert_operator pane_height("files"), :>=, 160
      assert_operator pane_height("notebooks"), :>=, 63
      assert_operator pane_height("folders"), :>=, 63
    end

    phase "3 minimums don't fit: the sidebar itself scrolls" do
      resize_height(300)
      assert scrolls?("#sidebarMenu > div"), "the sidebar wrapper should scroll"
      assert_operator pane_height("files"), :>=, 160
    end
  end

  private

    def resize_height(height)
      page.driver.browser.manage.window.resize_to(1400, height)
      wait_until("the window never reached #{height}px") { evaluate_script("window.outerHeight") <= height }
    end

    def pane_height(name)
      height = evaluate_script("document.querySelector('[data-sidebar-pane=\"#{name}\"]')?.getBoundingClientRect().height")
      assert height, "no [data-sidebar-pane=#{name}] element"
      height
    end

    def scrolls?(selector)
      evaluate_script("(el => el.scrollHeight > el.clientHeight)(document.querySelector('#{selector}'))")
    end
end
