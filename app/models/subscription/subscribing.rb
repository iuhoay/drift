# The factory side of Subscription: turning a pasted address into a live
# subscription. Kept out of the model body so subscription.rb stays a plain
# description of the record (associations, validation, presentation) while this
# concern owns the one multi-step write path.
module Subscription::Subscribing
  extend ActiveSupport::Concern

  class_methods do
    # Subscribes `user` to the feed behind a pasted address: resolves the address
    # to a real feed URL (auto-detecting when the user pasted a site, not a feed),
    # upserts the Feed and the join row in one transaction, and kicks off the
    # first fetch.
    #
    # Returns the Subscription — persisted on success, or an unsaved one carrying
    # validation errors when the address is blank, resolves to no feed, or a
    # record is invalid — so the caller branches on `persisted?` and re-renders.
    def subscribe(user, address, custom_title: nil)
      url = address.to_s.strip
      subscription = user.subscriptions.new

      if url.blank?
        subscription.errors.add(:feed_url, "can't be blank")
        return subscription
      end

      feed_url = Feed.resolve_url(url)

      if feed_url.blank?
        subscription.errors.add(:feed_url, "no feed found at that address")
        return subscription
      end

      feed = Feed.find_or_initialize_by(feed_url: feed_url)
      feed.title ||= feed_url

      transaction do
        feed.save!
        subscription = user.subscriptions.find_or_create_by!(feed: feed) do |s|
          s.custom_title = custom_title.presence
        end
      end

      FeedRefreshJob.perform_later(feed.id)
      subscription
    rescue ActiveRecord::RecordInvalid => e
      subscription.errors.add(:base, e.message)
      subscription
    end
  end
end
