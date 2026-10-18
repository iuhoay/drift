# Per-subscription Watch: email me when this feed publishes something new.
# The flag lives on the join. Fan-out lives on Feed (`notify_watchers_*`).
module Subscription::Watchable
  extend ActiveSupport::Concern

  included do
    scope :watched, -> { where(watched: true) }
  end

  def watch
    update!(watched: true) unless watched?
  end

  def unwatch
    update!(watched: false) if watched?
  end
end
