require "test_helper"

# An uptime monitor probes /up from outside with no session, so (like the PWA
# manifest) this stays signed out on purpose.
class HealthCheckTest < ActionDispatch::IntegrationTest
  test "/up answers 200 without authentication" do
    get "/up"

    assert_response :success
  end

  test "/up does not redirect to the login screen" do
    get "/up"

    assert_not response.redirect?
  end
end
