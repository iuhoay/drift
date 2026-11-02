require "test_helper"

class Subscription::WatchableTest < ActiveSupport::TestCase
  test "watch and unwatch toggle the flag" do
    subscription = subscriptions(:one_example)

    subscription.watch
    assert subscription.watched?

    subscription.unwatch
    assert_not subscription.watched?
  end
end
