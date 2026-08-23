require "test_helper"

# Covers ApplicationHelper#trusted_header_auth?/solo_deployment? and the
# Account tab content — server-rendered, so an integration test suffices.
class SettingsAccountTabTest < ActionDispatch::IntegrationTest
  setup { @original_header_env = ENV["TRUSTED_HEADER_AUTH_HEADER"] }
  teardown { ENV["TRUSTED_HEADER_AUTH_HEADER"] = @original_header_env }

  test "under normal password auth, the sign-out button is present and no trusted-header notice shows" do
    sign_in_as users(:one)

    get root_url

    assert_select "form[action=?][method=post] input[name=_method][value=delete]", session_path
    assert_no_match(/reverse proxy/, response.body)
  end

  test "under trusted-header solo auth, there's no sign-out button, and the notice names Just me" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
    owner = User.create!(email_address: "owner@example.com", password: "password", trusted_header_owner: true)

    get root_url, headers: { "Cf-Access-Authenticated-User-Email" => owner.email_address }

    assert_response :success
    assert_select "form[action=?][method=post]", session_path, count: 0
    assert_match I18n.t("setup.mode_solo"), response.body
  end

  test "under trusted-header team auth, there's no sign-out button, and the notice names My team" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
    # Team mode: per-email auto-provisioning, no trusted_header_owner flag
    # on anyone — see TrustedHeaderLogin#call.
    User.create!(email_address: "teammate-a@example.com", password: "password")
    User.create!(email_address: "teammate-b@example.com", password: "password")

    get root_url, headers: { "Cf-Access-Authenticated-User-Email" => "teammate-a@example.com" }

    assert_response :success
    assert_select "form[action=?][method=post]", session_path, count: 0
    assert_match I18n.t("setup.mode_team"), response.body
  end

  test "the email address always shows regardless of auth mode" do
    sign_in_as users(:one)

    get root_url

    assert_match users(:one).email_address, response.body
  end
end
