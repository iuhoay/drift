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
end
