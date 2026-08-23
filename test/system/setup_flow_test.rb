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

  test "team mode creates an admin account, with a plain username instead of an email" do
    visit new_setup_path

    choose I18n.t("setup.mode_team"), allow_label_click: true
    fill_in I18n.t("auth.email_or_username"), with: "it-admin"
    fill_in I18n.t("activerecord.attributes.user.password"), with: "password", match: :prefer_exact
    fill_in I18n.t("activerecord.attributes.user.password_confirmation"), with: "password"
    click_on I18n.t("setup.create_account")

    assert_text I18n.t("admin.users.title")
    assert_predicate User.last, :admin?
    assert_equal "it-admin", User.last.email_address
  end

  test "an admin account created with a username can sign back in with it" do
    visit new_setup_path
    choose I18n.t("setup.mode_team"), allow_label_click: true
    fill_in I18n.t("auth.email_or_username"), with: "it-admin"
    fill_in I18n.t("activerecord.attributes.user.password"), with: "password", match: :prefer_exact
    fill_in I18n.t("activerecord.attributes.user.password_confirmation"), with: "password"
    click_on I18n.t("setup.create_account")
    assert_text I18n.t("admin.users.title")

    click_on I18n.t("home.sign_out")

    # Sign-out redirects via Turbo, landing a beat after click_on returns —
    # wait for the field itself (not just any text on the page) before
    # typing into it, the same defensive wait sign_in_as uses elsewhere.
    assert_selector "input[name='email_address']:not([disabled])"
    fill_in I18n.t("auth.email_or_username"), with: "it-admin"
    fill_in I18n.t("activerecord.attributes.user.password"), with: "password"
    click_on I18n.t("sessions.sign_in")

    assert_text I18n.t("admin.users.title")
  end

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

  # Selenium can't fake a Cloudflare Access header — this is the scenario
  # a deployer would hit toggling this on before finishing reverse-proxy
  # setup; previously bitten by a Turbo-swallowed error response here.
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
