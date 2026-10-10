# A feed tells its watching subscribers when new entries land. The Watch
# flag itself lives on Subscription; this is only the fan-out.
module Feed::Watchable
  extend ActiveSupport::Concern

  # First successful parse is backfill — often months of history. Call this
  # before record_success so last_success_at still reflects prior state.
  def notify_watchers_later(entry_ids)
    return if last_success_at.blank?
    return if entry_ids.empty?
    return unless subscriptions.watched.exists?

    WatchNotifyJob.perform_later(id, entry_ids)
  end

  def notify_watchers_now(entry_ids)
    found = entries.where(id: entry_ids).to_a
    return if found.empty?

    subscriptions.watched.includes(:user).find_each do |subscription|
      WatchMailer.notify(subscription, found).deliver_later
    end
  end
end
