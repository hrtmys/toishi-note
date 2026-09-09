require "application_system_test_case"

class SetupFlowTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    User.destroy_all
  end

  test "solo mode creates a member account and lands on the notebook UI" do
    visit new_setup_path

    fill_in I18n.t("auth.email_or_username"), with: "solo@example.com"
    fill_in I18n.t("activerecord.attributes.user.password"), with: "password", match: :prefer_exact
    fill_in I18n.t("activerecord.attributes.user.password_confirmation"), with: "password"
    click_on I18n.t("setup.create_account")

    assert_selector "#sidebarMenuLabel", visible: :all
    assert_predicate User.last, :member?
  end

  # Team/usernames are covered by SetupControllerTest. The trusted-header
  # toggle is JS-only and the headerless submit guards error display.
  test "an invalid setup submission shows the error instead of nothing" do
    visit new_setup_path

    fill_in I18n.t("auth.email_or_username"), with: "solo@example.com"
    fill_in I18n.t("activerecord.attributes.user.password"), with: "password", match: :prefer_exact
    fill_in I18n.t("activerecord.attributes.user.password_confirmation"), with: "not the same"
    click_on I18n.t("setup.create_account")

    assert_text "Password confirmation doesn't match Password"
    assert_equal 0, User.count
  end

  test "the Cloudflare Access toggle only appears once trusted-header auth is configured, and hides the password fields when chosen" do
    visit new_setup_path
    assert_no_text I18n.t("setup.auth_method")

    with_trusted_header_auth do
      visit new_setup_path
      assert_text I18n.t("setup.auth_method")
      assert_field I18n.t("auth.email_or_username")

      choose I18n.t("setup.auth_method_trusted_header"), allow_label_click: true

      # Not by label text here: "Password" is also the other sign-in
      # method's radio label, still visible above — would ambiguously match.
      assert_no_selector "#user_email_address", visible: true
      assert_no_selector "#user_password", visible: true
      assert_no_selector "#user_password_confirmation", visible: true
    end
  end

  # The 422 itself is covered by SetupControllerTest — this proves the
  # error reaches the screen instead of being swallowed on the way.
  test "submitting Cloudflare Access without an actual trusted header shows an error instead of nothing" do
    with_trusted_header_auth do
      visit new_setup_path
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
