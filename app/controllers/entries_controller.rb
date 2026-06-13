class EntriesController < ApplicationController
  before_action :set_entry, only: :show

  PER_PAGE = 50

  def index
    @scope = params[:scope].presence_in(%w[all unread starred]) || "unread"
    @feed = Current.user.feeds.find_by(id: params[:feed_id]) if params[:feed_id]
    @query = params[:q].to_s.strip
    @on = parse_on(params[:on])
    @scope = "all" if @on

    entries = Current.user.subscribed_entries.includes(:feed)
    entries = entries.where(feed_id: @feed.id) if @feed
    if @on
      read_ids = Current.user.user_entries.where("read_at::date = ?", @on).select(:entry_id)
      entries = entries.where(id: read_ids)
    end
    entries = entries.search(@query) if @query.present?

    case @scope
    when "unread"
      entries = entries.where.not(id: read_entry_ids)
    when "starred"
      entries = entries.where(id: starred_entry_ids)
    end

    entries = entries.recent if @query.blank?

    @entries = entries.limit(PER_PAGE)
    @user_entries_by_id = Current.user.user_entries
                                      .where(entry_id: @entries.map(&:id))
                                      .index_by(&:entry_id)
  end

  def show
    # Read-only: marking read happens via a POST to Entries::ReadsController from
    # the view once the page is actually rendered. Keeps GET safe so Turbo's
    # hover prefetch can't mark entries read without the user opening them.
    @user_entry = Current.user.user_entries.find_by(entry: @entry)
  end

  private

  def set_entry
    @entry = Current.user.subscribed_entries.find(params[:id])
  end

  def parse_on(value)
    Date.iso8601(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

  def read_entry_ids
    Current.user.user_entries.read.select(:entry_id)
  end

  def starred_entry_ids
    Current.user.user_entries.starred.select(:entry_id)
  end
end
