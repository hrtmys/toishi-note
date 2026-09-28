require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Only for full serial runs (CI, bin/ci), so a scoped run stays quiet.
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
    # editorMode, lastPath and scroll positions otherwise leak between tests
    # through the shared Chrome profile.
    execute_script("localStorage.clear(); sessionStorage.clear()")
    fill_in I18n.t("auth.email_or_username"), with: user.email_address
    fill_in I18n.t("activerecord.attributes.user.password"), with: password
    click_on I18n.t("sessions.sign_in")
    assert_no_selector "input[name='email_address']"
  end

  # Smoke tests run many steps in one browser session; prefixing a failure
  # with its phase says where the run stopped.
  def phase(name)
    yield
  rescue Exception => error # rubocop:disable Lint/RescueException -- Minitest::Assertion is not a StandardError
    raise error.exception("phase #{name}: #{error.message}")
  end

  # Toasts fade out on their own, so assert on the event log rather than the
  # DOM. Call again after every full page load.
  def record_toasts
    execute_script(<<~JS)
      window.__toasts = []
      window.addEventListener("toast:show", (e) => window.__toasts.push(e.detail.message))
    JS
  end

  # Consumes the matched entry, so an earlier identical toast can't satisfy
  # a later assertion.
  def assert_toast(message)
    wait_until("toast never shown: #{message}") do
      evaluate_script("(window.__toasts || []).includes(#{message.to_json})")
    end
    execute_script("window.__toasts.splice(window.__toasts.indexOf(#{message.to_json}), 1)")
  end

  # Immediate check: only meaningful after an already-awaited outcome.
  def assert_no_toast(message)
    assert_not evaluate_script("(window.__toasts || []).includes(#{message.to_json})"),
      "unexpected toast: #{message}"
  end

  def force_fetch_rejection(only: nil)
    execute_script(<<~JS, only)
      const only = arguments[0]
      window.__realFetch ||= window.fetch.bind(window)
      window.fetch = (url, ...rest) => {
        if (only === null || String(url).includes(only)) return Promise.reject(new TypeError("Failed to fetch"))
        return window.__realFetch(url, ...rest)
      }
    JS
  end

  def restore_fetch
    execute_script("if (window.__realFetch) window.fetch = window.__realFetch")
  end

  def delay_fetch(ms)
    execute_script(<<~JS, ms)
      const ms = arguments[0]
      window.__realFetch ||= window.fetch.bind(window)
      window.fetch = (...args) => new Promise((resolve) => setTimeout(resolve, ms)).then(() => window.__realFetch(...args))
    JS
  end

  def spy_exec_command
    execute_script(<<~JS)
      window.__execCommandCalls = []
      window.__realExecCommand ||= document.execCommand.bind(document)
      document.execCommand = (...args) => {
        window.__execCommandCalls.push([ args[0], args[2] ])
        return window.__realExecCommand(...args)
      }
    JS
  end
end
