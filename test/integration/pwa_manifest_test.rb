require "test_helper"

# Browsers fetch the manifest before any session cookie exists (an install
# prompt can fire on the sign-in page), so this deliberately stays signed
# out — unlike almost every other integration test in this app.
class PwaManifestTest < ActionDispatch::IntegrationTest
  test "the manifest is served without authentication" do
    get "/manifest.json"

    assert_response :success
  end

  test "the manifest is JSON" do
    get "/manifest.json"

    assert_match %r{\Aapplication/json}, response.media_type
  end

  test "id, start_url and scope are all the root, so an installed app launches there" do
    get "/manifest.json"

    manifest = JSON.parse(response.body)
    assert_equal "/", manifest["id"]
    assert_equal "/", manifest["start_url"]
    assert_equal "/", manifest["scope"]
  end

  test "display is standalone" do
    get "/manifest.json"

    manifest = JSON.parse(response.body)
    assert_equal "standalone", manifest["display"]
  end

  test "theme_color and background_color are not the scaffold placeholder" do
    get "/manifest.json"

    manifest = JSON.parse(response.body)
    assert_not_equal "red", manifest["theme_color"]
    assert_not_equal "red", manifest["background_color"]
  end

  test "every icon's declared sizes matches the real pixel dimensions of its file" do
    get "/manifest.json"

    manifest = JSON.parse(response.body)
    icons = manifest["icons"]
    assert icons.present?, "expected the manifest to declare at least one icon"

    icons.each do |icon|
      width, height = png_dimensions(Rails.root.join("public", icon["src"].delete_prefix("/")))
      assert_equal "#{width}x#{height}", icon["sizes"],
        "declared sizes for #{icon['src']} does not match its real dimensions"
    end
  end

  private

    # Reads width/height straight out of the PNG IHDR chunk (bytes 16..23 of
    # any valid PNG) rather than shelling out to an image library the test
    # environment may not have — this only needs to read, not decode, the file.
    def png_dimensions(path)
      bytes = File.binread(path, 24)
      bytes[16, 8].unpack("N2")
    end
end
