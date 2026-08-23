require "test_helper"

class TrustedHeaderAuthenticationTest < ActionDispatch::IntegrationTest
  setup { @original_header_env = ENV["TRUSTED_HEADER_AUTH_HEADER"] }
  teardown { ENV["TRUSTED_HEADER_AUTH_HEADER"] = @original_header_env }

  test "a request carrying the trusted header is let straight through, no login screen" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"

    assert_difference("User.count") do
      get root_url, headers: { "Cf-Access-Authenticated-User-Email" => "proxy-vouched@example.com" }
    end

    assert_response :success
    assert cookies[:session_id]
  end

  test "without the header, an unauthenticated request still hits the login screen" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"

    get root_url

    assert_redirected_to new_session_path
  end

  test "a trusted header alone never creates the very first account — that only ever happens through Setup" do
    User.destroy_all
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"

    assert_no_difference("User.count") do
      get root_url, headers: { "Cf-Access-Authenticated-User-Email" => "first-visitor@example.com" }
    end

    assert_redirected_to new_setup_path
  end

  test "an existing session cookie is trusted over the header on later requests" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
    sign_in_as users(:one)

    get root_url, headers: { "Cf-Access-Authenticated-User-Email" => "someone-else@example.com" }

    assert_response :success
    assert_no_difference("User.count") { get root_url, headers: { "Cf-Access-Authenticated-User-Email" => "someone-else@example.com" } }
  end
end
