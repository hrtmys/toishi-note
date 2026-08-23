require "application_system_test_case"

class AdminPanelTest < ApplicationSystemTestCase
  setup do
    page.driver.browser.manage.window.resize_to(1400, 1000)
    sign_in_as users(:admin)
  end

  test "inviting a teammate shows the one-time link on screen" do
    visit new_admin_user_path

    fill_in I18n.t("auth.email_or_username"), with: "newcomer@example.com"
    click_on I18n.t("admin.users.new.create_invite_link")

    assert_text I18n.t("admin.users.invited.heading", email: "newcomer@example.com")
    assert_selector "input[readonly][value*='/passwords/']"
  end

  test "an invalid invite shows the error instead of nothing" do
    visit new_admin_user_path

    fill_in I18n.t("auth.email_or_username"), with: users(:one).email_address
    click_on I18n.t("admin.users.new.create_invite_link")

    assert_text "Email address has already been taken"
    assert_current_path admin_users_path
  end

  test "issuing a teammate a reset link shows it on screen" do
    visit admin_users_path

    within "li", text: users(:one).email_address do
      click_on I18n.t("admin.users.create_reset_link")
    end

    assert_text I18n.t("admin.users.password_reset_link.heading", email: users(:one).email_address)
    assert_selector "input[readonly][value*='/passwords/']"
  end

  test "removing a teammate takes them off the list and warns their notebooks go with them" do
    orphaned_notebook_id = notebooks(:one).id
    visit admin_users_path
    assert_text users(:one).email_address

    within "li", text: users(:one).email_address do
      accept_confirm(/permanently deletes 1 notebook/) { click_on I18n.t("admin.users.remove") }
    end

    assert_no_selector "li", text: users(:one).email_address
    assert_not Notebook.exists?(orphaned_notebook_id)
  end

  test "an admin can't remove their own account from the UI" do
    visit admin_users_path

    within "li", text: users(:admin).email_address do
      assert_no_button I18n.t("admin.users.remove")
    end
  end

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
