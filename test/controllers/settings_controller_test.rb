require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "enables the editor FAB" do
    patch settings_url, params: { editor_fab_enabled: true }, as: :json
    assert_response :success
    assert users(:one).reload.editor_fab_enabled?
  end

  test "disables the editor FAB" do
    users(:one).update!(editor_fab_enabled: true)

    patch settings_url, params: { editor_fab_enabled: false }, as: :json
    assert_response :success
    assert_not users(:one).reload.editor_fab_enabled?
  end

  test "toggles table_paste_enabled" do
    patch settings_url, params: { table_paste_enabled: true }, as: :json
    assert_response :success
    assert users(:one).reload.table_paste_enabled?

    patch settings_url, params: { table_paste_enabled: false }, as: :json
    assert_not users(:one).reload.table_paste_enabled?
  end

  test "toggles keep_original_images" do
    patch settings_url, params: { keep_original_images: true }, as: :json
    assert_response :success
    assert users(:one).reload.keep_original_images?

    patch settings_url, params: { keep_original_images: false }, as: :json
    assert_not users(:one).reload.keep_original_images?
  end

  test "only ever updates the signed-in user, and ignores unrelated params" do
    patch settings_url, params: { editor_fab_enabled: true, role: "admin" }, as: :json

    users(:one).reload
    assert users(:one).editor_fab_enabled?
    assert users(:one).member?
  end

  test "changes the locale" do
    patch settings_url, params: { locale: "ja" }, as: :json
    assert_response :success
    assert_equal "ja", users(:one).reload.locale
  end

  test "rejects an unsupported locale" do
    patch settings_url, params: { locale: "fr" }, as: :json

    assert_response :unprocessable_entity
    # "en", not "fr" or nil — the rejected update never took, but
    # resolving this request's own locale backfills the blank value.
    assert_equal "en", users(:one).reload.locale
  end
end
