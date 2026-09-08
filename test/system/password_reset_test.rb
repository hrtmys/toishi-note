require "application_system_test_case"

class PasswordResetTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
  end

  # The username-based request path is covered by PasswordsControllerTest
  # ("create works for a username-based account too"), and the plain text
  # field it depends on is locked by its "new" test's assert_select — no
  # browser needed for either. Only page-to-page navigation stays here.
  test "the forgot-password page always has a way back to sign in" do
    visit new_password_path
    click_on I18n.t("passwords.back_to_sign_in")

    assert_current_path new_session_path
    assert_selector "input[name='email_address']"
  end
end
