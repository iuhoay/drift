ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/feed_discovery_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # assert_enqueued_with and friends in model tests (integration tests get these
    # for free). Used to assert subscribe/refresh enqueues a FeedRefreshJob.
    include ActiveJob::TestHelper

    # stub_discovery — swap Feed::Discovery.call for a canned result in any test.
    include FeedDiscoveryTestHelper
  end
end
