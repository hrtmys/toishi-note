require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  test "renders the setup form when no users exist yet" do
    User.destroy_all
    get new_setup_path
    assert_response :success
  end

  test "redirects to login once a user already exists" do
    get new_setup_path
    assert_redirected_to new_session_path
  end

  test "creates the first account and signs in" do
    User.destroy_all

    assert_difference("User.count") do
      post setup_path, params: { user: { email_address: "owner@example.com", password: "password", password_confirmation: "password" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "defaults to a member account when no mode is given" do
    User.destroy_all

    post setup_path, params: { user: { email_address: "owner@example.com", password: "password", password_confirmation: "password" } }

    assert_predicate User.last, :member?
  end

  test "mode: solo creates a note-taking member account" do
    User.destroy_all

    post setup_path, params: { mode: "solo", user: { email_address: "solo@example.com", password: "password", password_confirmation: "password" } }

    assert_predicate User.last, :member?
  end

  test "mode: team creates an admin account that lands on the admin panel" do
    User.destroy_all

    post setup_path, params: { mode: "team", user: { email_address: "owner@example.com", password: "password", password_confirmation: "password" } }

    assert_predicate User.last, :admin?
    follow_redirect!
    assert_redirected_to admin_users_path
  end

  test "refuses to create a second account once one already exists" do
    assert_no_difference("User.count") do
      post setup_path, params: { user: { email_address: "second@example.com", password: "password", password_confirmation: "password" } }
    end

    assert_redirected_to new_session_path
  end

  test "re-renders with errors on invalid input" do
    User.destroy_all

    assert_no_difference("User.count") do
      post setup_path, params: { user: { email_address: "", password: "password", password_confirmation: "password" } }
    end

    assert_response :unprocessable_entity
  end

  test "auth_mode: trusted_header, mode: solo creates the owner-flagged account from the request header, no password form needed" do
    User.destroy_all
    with_trusted_header_auth do
      assert_difference("User.count") do
        post setup_path, params: { auth_mode: "trusted_header", mode: "solo" }, headers: { "Cf-Access-Authenticated-User-Email" => "owner@example.com" }
      end

      assert_redirected_to root_path
      assert cookies[:session_id]
      assert_predicate User.last, :trusted_header_owner?
      assert_equal "owner@example.com", User.last.email_address
    end
  end

  test "auth_mode: trusted_header, mode: team provisions a plain (non-owner) account, same as any later teammate" do
    User.destroy_all
    with_trusted_header_auth do
      post setup_path, params: { auth_mode: "trusted_header", mode: "team" }, headers: { "Cf-Access-Authenticated-User-Email" => "first-teammate@example.com" }

      assert_not_predicate User.last, :trusted_header_owner?
      assert_predicate User.last, :member?
    end
  end

  test "auth_mode: trusted_header re-renders with an error when the request has no trusted header" do
    User.destroy_all
    with_trusted_header_auth do
      assert_no_difference("User.count") do
        post setup_path, params: { auth_mode: "trusted_header", mode: "solo" }
      end

      assert_response :unprocessable_entity
    end
  end

  test "auth_mode: trusted_header is ignored (falls back to password validation) when trusted-header auth isn't configured" do
    User.destroy_all

    # The real form's password fields stay present (CSS-hidden) even under
    # Cloudflare Access, submitting blanks — simulate that shape rather
    # than omitting `user`, which would just 400 on a missing param.
    assert_no_difference("User.count") do
      post setup_path, params: { auth_mode: "trusted_header", mode: "solo", user: { email_address: "", password: "", password_confirmation: "" } },
        headers: { "Cf-Access-Authenticated-User-Email" => "owner@example.com" }
    end

    assert_response :unprocessable_entity
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
