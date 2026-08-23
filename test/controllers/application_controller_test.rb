require "test_helper"

# Locale detection/persistence — see ApplicationController#switch_locale.
# Exercised against new_session_path (pre-auth) except where a test is
# specifically about a signed-in user's own preference.
class ApplicationControllerLocaleTest < ActionDispatch::IntegrationTest
  test "defaults to English with no signed-in user, no cookie, and no Accept-Language header" do
    get new_session_path

    assert_equal "en", cookies[:locale]
    assert_select "html[lang=?]", "en"
  end

  test "detects Japanese from the Accept-Language header" do
    get new_session_path, headers: { "Accept-Language" => "ja" }

    assert_equal "ja", cookies[:locale]
    assert_select "html[lang=?]", "ja"
  end

  test "prefers the higher-quality language in a multi-language Accept-Language header" do
    get new_session_path, headers: { "Accept-Language" => "fr;q=0.9,ja;q=0.5,en;q=0.3" }

    assert_equal "ja", cookies[:locale]
  end

  test "falls back to English when Accept-Language names only unsupported locales" do
    get new_session_path, headers: { "Accept-Language" => "fr,de;q=0.8" }

    assert_equal "en", cookies[:locale]
  end

  test "an existing locale cookie is respected over a differing Accept-Language header" do
    cookies[:locale] = "ja"
    get new_session_path, headers: { "Accept-Language" => "en" }

    assert_equal "ja", cookies[:locale]
    assert_select "html[lang=?]", "ja"
  end

  test "an invalid locale cookie is ignored, falling back to detection" do
    cookies[:locale] = "not-a-real-locale"
    get new_session_path, headers: { "Accept-Language" => "ja" }

    assert_equal "ja", cookies[:locale]
  end

  test "a signed-in user's own locale wins over their cookie" do
    sign_in_as users(:one)
    users(:one).update!(locale: "ja")
    cookies[:locale] = "en"

    get root_url

    assert_select "html[lang=?]", "ja"
  end

  test "backfills a signed-in user's locale from Accept-Language the first time it's unset" do
    user = users(:one)
    assert_nil user.locale
    sign_in_as user

    get root_url, headers: { "Accept-Language" => "ja" }

    assert_equal "ja", user.reload.locale
    assert_equal "ja", cookies[:locale]
  end

  test "does not touch a signed-in user's locale once it's already set" do
    user = users(:one)
    user.update!(locale: "en")
    sign_in_as user

    get root_url, headers: { "Accept-Language" => "ja" }

    assert_equal "en", user.reload.locale
  end
end
