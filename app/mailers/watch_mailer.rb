class WatchMailer < ApplicationMailer
  MAX_ENTRIES = 20

  def notify(subscription, entries)
    @subscription = subscription
    all = Array(entries)
    @total = all.size
    @entries = all.first(MAX_ENTRIES)
    @remainder = @total - @entries.size
    return if @entries.empty? || !@subscription.watched?

    mail to: @subscription.user.email_address, subject: subject_line
  end

  private
    def subject_line
      title = @subscription.display_title
      if @total == 1
        "#{title}: #{@entries.first.title}".truncate(80)
      else
        "#{title}: #{@total} new"
      end
    end
end
