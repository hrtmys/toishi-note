require "application_system_test_case"

class PasswordResetTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  # The username POST path and its text-field guard live in
  # PasswordsControllerTest — only page-to-page navigation stays here.
  test "the forgot-password page always has a way back to sign in" do
    visit new_password_path
    click_on I18n.t("passwords.back_to_sign_in")

    assert_current_path new_session_path
    assert_selector "input[name='email_address']"
  end
end
