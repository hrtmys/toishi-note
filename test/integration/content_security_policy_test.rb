require "test_helper"

# The system test (test/system/security_test.rb) proves the policy
# blocks inline scripts in a real browser. This complements it at the
# HTTP layer, checking the exact directives the CSP middleware sends.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the CSP header is sent on a real page response with the expected directives" do
    get root_url

    policy = response.headers["Content-Security-Policy"]
    assert_not_nil policy, "expected a Content-Security-Policy header on the response"

    # script-src is exactly "'self'" — a regression adding unsafe_inline
    # would reopen the XSS class this closes. Anchored to end-of-directive
    # so this doesn't match style-src's legitimate unsafe-inline.
    assert_match(/script-src 'self'(;|\z)/, policy)
    assert_match "default-src 'self'", policy
    assert_match "object-src 'none'", policy
    assert_match "frame-ancestors 'self'", policy

    # style-src needs 'unsafe-inline' for Bootstrap style="..." and
    # KaTeX/Mermaid's inline styles. Asserts the *reason* stays true, not
    # just the current directive.
    assert_match "style-src 'self' 'unsafe-inline'", policy
  end

  test "the policy is enforced, and script-src allows no inline, eval, nonce, hash or wildcard source" do
    get root_url

    assert_nil response.headers["Content-Security-Policy-Report-Only"]
    script_src = response.headers["Content-Security-Policy"][/script-src ([^;]*)/, 1]
    assert_not_nil script_src
    [ "'unsafe-inline'", "'unsafe-eval'", "'strict-dynamic'", "'nonce-", "'sha256-", "*", "data:", "https:" ].each do |source|
      assert_not_includes script_src, source
    end
  end

  test "the CSP header is also sent on the palette frame response" do
    get palette_url(q: "x")

    assert_response :success
    assert_match(/script-src 'self'(;|\z)/, response.headers["Content-Security-Policy"])
  end

  test "the CSP header is sent even on the sign-in page, before authentication" do
    sign_out
    get new_session_url

    assert_not_nil response.headers["Content-Security-Policy"]
  end
end
