require "test_helper"

# Locks in that the Ctrl+P palette can never surface another account's
# notes, no matter what's searched for — same style as
# notebook_privacy_test.rb, but for a read path.
class PalettePrivacyTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the MRU (blank query) list never includes another account's notes" do
    get palette_url

    assert_response :success
    assert_match notes(:one).title, response.body
    assert_no_match notes(:two).title, response.body
  end

  test "searching for another account's note title returns nothing" do
    get palette_url, params: { q: notes(:two).title }

    assert_response :success
    assert_no_match notes(:two).title, response.body
  end

  test "searching for another account's note title by a shared substring still excludes it" do
    # Both fixtures are titled "Note One" / "Note Two" — "Note" alone is
    # a substring of both, so this proves the exclusion isn't just an
    # accident of the two titles never overlapping.
    get palette_url, params: { q: "Note" }

    assert_response :success
    assert_match notes(:one).title, response.body
    assert_no_match notes(:two).title, response.body
  end
end
