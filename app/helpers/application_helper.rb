module ApplicationHelper
  def unread_counts_for(user)
    return {} unless user

    read_ids = user.user_entries.read.select(:entry_id)
    user.subscribed_entries.where.not(id: read_ids).group(:feed_id).count
  end

  def total_unread_for(user)
    unread_counts_for(user).values.sum
  end

  def starred_count_for(user)
    user.user_entries.starred.count
  end

  def relative_time(time)
    return nil unless time

    distance = Time.current - time
    case distance
    when ...60        then "just now"
    when 60...3600    then "#{(distance / 60).round}m"
    when 3600...86400 then "#{(distance / 3600).round}h"
    when 86400...604800 then "#{(distance / 86400).round}d"
    else                   time.strftime("%b %-d")
    end
  end

  # Forward-looking counterpart to relative_time: "in 4m", "in 21h", "in 3d".
  # Used for next_fetch_at, which is always in the future for a backed-off feed.
  def time_until(time)
    return nil unless time

    distance = time - Time.current
    case distance
    when ..0       then "now"
    when ...3600   then "in #{(distance / 60).round}m"
    when ...86400  then "in #{(distance / 3600).round}h"
    when ...604800 then "in #{(distance / 86400).round}d"
    else                "on #{time.strftime('%b %-d')}"
    end
  end
end
