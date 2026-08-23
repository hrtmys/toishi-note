require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |driver_options|
    driver_options.add_argument("--no-sandbox")
    driver_options.add_argument("--disable-dev-shm-usage")
    driver_options.add_argument("--disable-gpu")
  end

  # Shared CI runners are slower/noisier than a devcontainer: a click
  # landing before its listener attaches, or a round trip exceeding the
  # wait budget under load. Raised here for the whole suite.
  Capybara.default_max_wait_time = 8

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
