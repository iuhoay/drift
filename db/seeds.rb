user = User.find_or_create_by!(email_address: "demo@drift.local") do |u|
  u.password = "drift1234"
  u.password_confirmation = "drift1234"
end

starter_feeds = [
  "https://daringfireball.net/feeds/main",
  "https://world.hey.com/dhh/feed.atom",
  "https://blog.cleancoder.com/atom.xml"
]

starter_feeds.each do |url|
  feed = Feed.find_or_initialize_by(feed_url: url)
  feed.title ||= url
  feed.save!
  Subscription.find_or_create_by!(user: user, feed: feed)
  FeedRefreshJob.perform_later(feed.id)
end

puts "Seeded user demo@drift.local / drift1234 with #{user.subscriptions.count} feeds."
