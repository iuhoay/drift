require "test_helper"

class SubscriptionsHelperTest < ActionView::TestCase
  test "uncategorized subscriptions are a single unlabeled section" do
    subs = [ subscriptions(:one_example) ]

    assert_equal [ [ nil, subs ] ], subscription_nav_sections(subs)
  end

  test "groups by case-insensitive category and parks the rest unlabeled" do
    apple = subscriptions(:one_stale)
    other = subscriptions(:one_example)
    also_apple = subscriptions(:two_example)
    also_apple.category = "apple"

    sections = subscription_nav_sections([ other, also_apple, apple ])

    assert_equal 2, sections.size
    assert_equal "apple", sections.first.first
    assert_equal [ also_apple, apple ], sections.first.last
    assert_equal [ nil, [ other ] ], sections.last
  end
end
