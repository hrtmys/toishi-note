ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

# CI-only: retries a failed system test in place once before giving up.
# Gated on ENV["CI"] so a genuinely broken test still fails immediately
# for a developer looking locally.
if ENV["CI"]
  require "minitest/retry"
  Minitest::Retry.use!(retry_count: 2, classes_to_retry: [ "ApplicationSystemTestCase" ])
end

module ActiveSupport
  class TestCase
    # Overridable via PARALLEL_WORKERS — CI's system-test job sets this
    # to 1, since its 2-CPU runner exceeds Capybara's wait budget with
    # multiple parallel Chrome instances.
    parallelize(workers: ENV["PARALLEL_WORKERS"]&.to_i || :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
