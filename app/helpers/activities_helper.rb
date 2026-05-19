module ActivitiesHelper
  # Columns of 7 days (Sun..Sat), GitHub-style. Days past `end_date` in the
  # trailing week are nil so the grid stays rectangular.
  def activity_weeks(start_date, end_date, counts)
    (start_date..end_date).each_slice(7).map do |week|
      Array.new(7) do |i|
        date = week.first + i
        next nil if date > end_date

        count = counts[date].to_i
        { date: date, count: count, level: activity_level(count) }
      end
    end
  end

  def activity_level(count)
    case count
    when 0    then 0
    when 1..2 then 1
    when 3..5 then 2
    when 6..9 then 3
    else           4
    end
  end

  # One label per week column: the month abbreviation when a new month starts
  # in that column, otherwise nil.
  def activity_month_labels(weeks)
    previous = nil
    weeks.map do |week|
      first = week.compact.first
      next nil unless first

      month = first[:date].strftime("%b")
      (month == previous) ? nil : (previous = month)
    end
  end
end
