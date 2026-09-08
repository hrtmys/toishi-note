require "application_system_test_case"

class AdminPanelTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:admin)
  end

  # Invite / invalid-invite / reset-link / remove / self-remove are all
  # covered by Admin::UsersControllerTest (10 tests, including the
  # readonly one-time-link inputs locked via assert_select above) — no
  # browser needed. Only the JS-only navigation hijack stays here: it
  # needs a real localStorage + Turbo navigation, which no
  # controller test can provide.
  test "a stale lastPath from a previous note-editor visit doesn't yank the admin off this page" do
    # localStorage is shared per browser origin, not per account — a value
    # left over from an earlier login (or a member account on the same
    # browser) must not hijack navigation here. See navigation_controller.js.
    page.execute_script("window.localStorage.setItem('lastPath', window.location.origin + '/?notebook_id=1&note_id=1')")

    visit new_admin_user_path
    assert_selector "h1", text: I18n.t("admin.users.new.title")

    fill_in I18n.t("auth.email_or_username"), with: "newcomer@example.com"
    click_on I18n.t("admin.users.new.create_invite_link")

    assert_text I18n.t("admin.users.invited.heading", email: "newcomer@example.com")
  end
end
