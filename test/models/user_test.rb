require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "assigns registered_at on create when not given" do
    user = User.create!(email_address: "new@example.com", password: "password")
    assert_not_nil user.registered_at
  end

  test "does not overwrite an explicitly given registered_at" do
    registered_at = 3.days.ago
    user = User.create!(email_address: "backfilled@example.com", password: "password", registered_at: registered_at)
    assert_in_delta registered_at, user.registered_at, 1.second
  end

  test "defaults to the member role" do
    assert_predicate User.new, :member?
  end

  test "locale must be one of the app's supported locales, or left blank" do
    user = User.new(email_address: "locale-check@example.com", password: "password")
    assert user.valid?, "expected a blank locale to be valid"

    user.locale = "ja"
    assert user.valid?

    user.locale = "fr"
    assert_not user.valid?
    assert_includes user.errors[:locale], "is not included in the list"
  end

  test "destroying a user destroys their notebooks — notebooks aren't shared, so nothing else references them" do
    user = User.create!(email_address: "owner@example.com", password: "password")
    user.notebooks.create!(name: "Private Notebook")

    assert_difference("Notebook.count", -1) do
      user.destroy
    end
  end

  test "password_reset_token — used for invites and rescue links — lives long enough to sit in chat unread" do
    user = users(:one)
    token = user.password_reset_token

    travel 23.hours do
      assert_equal user, User.find_by_password_reset_token!(token)
    end

    travel 25.hours do
      assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
        User.find_by_password_reset_token!(token)
      end
    end
  end
end
