require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "requires an existing session" do
    get admin_users_path
    assert_redirected_to new_session_path
  end

  test "blocks a member account from the admin panel" do
    sign_in_as users(:one)

    get admin_users_path

    assert_redirected_to root_path
  end

  test "member accounts can't invite or issue reset links either" do
    sign_in_as users(:one)

    assert_no_difference("User.count") do
      post admin_users_path, params: { user: { email_address: "sneaky@example.com" } }
    end
    assert_redirected_to root_path

    post password_reset_link_admin_user_path(users(:two))
    assert_redirected_to root_path

    assert_no_difference("User.count") do
      delete admin_user_path(users(:two))
    end
    assert_redirected_to root_path
  end

  test "an admin sees the team list" do
    sign_in_as users(:admin)

    get admin_users_path

    assert_response :success
  end

  test "an admin invites a teammate without ever choosing their password" do
    sign_in_as users(:admin)

    assert_difference("User.count") do
      post admin_users_path, params: { user: { email_address: "newcomer@example.com" } }
    end

    invited = User.find_by(email_address: "newcomer@example.com")
    assert_predicate invited, :member?
    assert_response :success

    # The shown link's token actually resolves to the invited user, so they
    # (and only they, holding the link) can set their own password with it.
    assert_equal invited, User.find_by_password_reset_token!(token_shown_in_response)
  end

  test "inviting a teammate doesn't touch the admin's own session" do
    sign_in_as users(:admin)
    original_session_cookie = cookies[:session_id]

    post admin_users_path, params: { user: { email_address: "newcomer@example.com" } }

    assert_equal original_session_cookie, cookies[:session_id]
  end

  test "re-renders with errors on invalid input" do
    sign_in_as users(:admin)

    assert_no_difference("User.count") do
      post admin_users_path, params: { user: { email_address: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "an admin can issue a locked-out teammate a fresh reset link" do
    sign_in_as users(:admin)

    post password_reset_link_admin_user_path(users(:one))

    assert_response :success
    assert_equal users(:one), User.find_by_password_reset_token!(token_shown_in_response)
  end

  test "an admin removes a teammate" do
    sign_in_as users(:admin)

    assert_difference("User.count", -1) do
      delete admin_user_path(users(:one))
    end

    assert_redirected_to admin_users_path
  end

  test "an admin can't remove their own account, even by posting the route directly" do
    sign_in_as users(:admin)

    assert_no_difference("User.count") do
      delete admin_user_path(users(:admin))
    end

    assert_redirected_to admin_users_path
    assert Session.exists?(user: users(:admin)), "removing themselves shouldn't have signed the admin out"
  end

  private
    # generates_token_for embeds an expiry, so regenerating a token to
    # compare against the response never matches the one actually shown —
    # pull the real one out of the rendered link instead.
    def token_shown_in_response
      @response.body[%r{/passwords/([^/"]+)/edit}, 1]
    end
end
