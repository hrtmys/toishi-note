require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Only under the CI/bin/ci-driven serial run: a scoped
  # `bin/rails test test/system/x_test.rb` stays quiet (plan-opus.md §2.2).
  SystemBudget.install!(test_case: self) if ENV["SYSTEM_BUDGET"] == "1"

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |driver_options|
    driver_options.add_argument("--no-sandbox")
    driver_options.add_argument("--disable-dev-shm-usage")
    driver_options.add_argument("--disable-gpu")
  end

  # Shared CI runners are slower/noisier than a devcontainer: a click
  # landing before its listener attaches, or a round trip exceeding the
  # wait budget under load. Raised here for the whole suite.
  Capybara.default_max_wait_time = 8

  # The browser window outlives each test, so one that resizes it (to a phone
  # width, say) would otherwise leave the next test with a hidden sidebar.
  setup { page.driver.browser.manage.window.resize_to(1400, 1400) }

  # `visit` only waits for `load`, not our JS bundle — a click right after
  # can land before its listener attaches. Waiting for `window.Stimulus`
  # (set once the bundle runs) closes that gap.
  def visit(*)
    super
    wait_for_javascript
  end

  def wait_for_javascript
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.01 until evaluate_script("typeof window.Stimulus !== 'undefined'")
    end
  end

  # For conditions no Capybara matcher can see (a DB row, a scroll
  # offset, a transient textarea value). The message must name the
  # awaited save or render — a bare Timeout::Error says nothing.
  def wait_until(message)
    Timeout.timeout(Capybara.default_max_wait_time, nil, message) do
      sleep 0.05 until yield
    end
  end

  # System tests run a real separate browser process, so
  # SessionTestHelper's cookie-jar trick can't reach it — sign in through
  # the form instead, waiting for it to disappear before the next `visit`.
  def sign_in_as(user, password: "password")
    visit new_session_path
    fill_in I18n.t("auth.email_or_username"), with: user.email_address
    fill_in I18n.t("activerecord.attributes.user.password"), with: password
    click_on I18n.t("sessions.sign_in")
    assert_no_selector "input[name='email_address']"
  end
end
