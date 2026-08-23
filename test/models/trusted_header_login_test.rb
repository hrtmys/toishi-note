require "test_helper"

class TrustedHeaderLoginTest < ActiveSupport::TestCase
  setup { @original_header_env = ENV["TRUSTED_HEADER_AUTH_HEADER"] }
  teardown { ENV["TRUSTED_HEADER_AUTH_HEADER"] = @original_header_env }

  test "does nothing when disabled" do
    ENV.delete("TRUSTED_HEADER_AUTH_HEADER")
    request = build_request("Cf-Access-Authenticated-User-Email" => "someone@example.com")

    assert_nil TrustedHeaderLogin.new(request).call
  end

  test "auto-provisions a user from the configured header" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
    request = build_request("Cf-Access-Authenticated-User-Email" => "new-teammate@example.com")

    assert_difference("User.count") do
      user = TrustedHeaderLogin.new(request).call
      assert_equal "new-teammate@example.com", user.email_address
      # A trusted proxy vouches for identity, not for a role — an admin
      # account still requires a deliberate action (setup or an invite).
      assert_predicate user, :member?
    end
  end

  test "reuses the existing user on a later request instead of creating a duplicate" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
    existing = users(:one)
    request = build_request("Cf-Access-Authenticated-User-Email" => existing.email_address)

    assert_no_difference("User.count") do
      assert_equal existing, TrustedHeaderLogin.new(request).call
    end
  end

  test "does nothing when the header is absent from the request" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
    request = build_request({})

    assert_nil TrustedHeaderLogin.new(request).call
  end

  test "pins every request to the trusted-header owner regardless of which email the header reports" do
    ENV["TRUSTED_HEADER_AUTH_HEADER"] = "Cf-Access-Authenticated-User-Email"
    owner = users(:one)
    owner.update!(trusted_header_owner: true)
    request = build_request("Cf-Access-Authenticated-User-Email" => "a-different-verified-email@example.com")

    assert_no_difference("User.count") do
      assert_equal owner, TrustedHeaderLogin.new(request).call
    end
  end

  private
    def build_request(headers)
      ActionDispatch::TestRequest.create.tap do |request|
        headers.each { |name, value| request.headers[name] = value }
      end
    end
end
