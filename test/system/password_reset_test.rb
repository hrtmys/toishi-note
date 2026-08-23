require "application_system_test_case"

class PasswordResetTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  test "requesting a reset link works with a plain username, not just an email address" do
    # A company admin account frequently has no separate email address —
    # this form once regressed to an HTML5 email_field that silently
    # blocked anything without an "@" before submit.
    User.create!(email_address: "it-admin", password: "password", role: :admin)

    visit new_password_path
    fill_in I18n.t("auth.email_or_username"), with: "it-admin"
    click_on I18n.t("passwords.email_reset_instructions")

    assert_current_path new_session_path
    assert_text I18n.t("passwords.flash.instructions_sent")
  end

  test "the forgot-password page always has a way back to sign in" do
    visit new_password_path
    click_on I18n.t("passwords.back_to_sign_in")

    assert_current_path new_session_path
    assert_selector "input[name='email_address']"
  end
end
