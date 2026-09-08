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

  # Team/usernames, sign-in-with-username, and both trusted-header paths
  # are covered by SetupControllerTest (12 tests, including the 422
  # re-renders) — no browser needed. Only the first-run landing and the
  # Turbo error display stay here.
  test "an invalid setup submission shows the error instead of nothing" do
    visit new_setup_path

    fill_in I18n.t("auth.email_or_username"), with: "solo@example.com"
    fill_in I18n.t("activerecord.attributes.user.password"), with: "password", match: :prefer_exact
    fill_in I18n.t("activerecord.attributes.user.password_confirmation"), with: "not the same"
    click_on I18n.t("setup.create_account")

    assert_text "Password confirmation doesn't match Password"
    assert_equal 0, User.count
  end
end
