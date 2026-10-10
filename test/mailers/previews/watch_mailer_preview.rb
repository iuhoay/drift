# Preview all emails at http://localhost:3000/rails/mailers/watch_mailer
class WatchMailerPreview < ActionMailer::Preview
  def notify
    subscription = Subscription.watched.includes(:feed, :user).first || Subscription.includes(:feed, :user).first
    entries = subscription.feed.entries.recent.limit(3).to_a
    entries = subscription.feed.entries.limit(3).to_a if entries.empty?
    WatchMailer.notify(subscription, entries)
  end
end
