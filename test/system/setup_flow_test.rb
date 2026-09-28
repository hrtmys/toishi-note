require "application_system_test_case"

class SetupFlowTest < ApplicationSystemTestCase
  PASSWORD_FIELDS = %w[#user_email_address #user_password #user_password_confirmation].freeze

  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    User.destroy_all
  end

  test "choosing Cloudflare Access hides the password fields and lets the form submit" do
    with_trusted_header_auth do
      visit new_setup_path
      PASSWORD_FIELDS.each { |field| assert_selector "#{field}[required]", visible: true }

      choose I18n.t("setup.auth_method_trusted_header"), allow_label_click: true
      PASSWORD_FIELDS.each { |field| assert_no_selector field, visible: true }

      choose I18n.t("setup.auth_method_password"), allow_label_click: true
      PASSWORD_FIELDS.each { |field| assert_selector "#{field}[required]", visible: true }

      # Reaching the server's error proves the hidden fields no longer block submission.
      choose I18n.t("setup.auth_method_trusted_header"), allow_label_click: true
      click_on I18n.t("setup.create_account")
      assert_text I18n.t("setup.trusted_header_missing")
      assert_equal 0, User.count
    end
  end

  private
    def with_trusted_header_auth
      original = ENV["TRUSTED_HEADER_AUTH_HEADER"]
      ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
      yield
    ensure
      ENV["TRUSTED_HEADER_AUTH_HEADER"] = original
    end
end
