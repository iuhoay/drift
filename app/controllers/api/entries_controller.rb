class Api::EntriesController < Api::BaseController
  def index
    scope = params[:scope].presence_in(%w[all unread starred]) || "unread"
    feed = current_user.feeds.find_by(id: params[:feed_id]) if params[:feed_id]
    query = params[:q].to_s.strip
    limit = (params[:limit] || 20).to_i.clamp(1, 50)

    entries = current_user.subscribed_entries.includes(:feed)
    entries = entries.where(feed_id: feed.id) if feed
    entries = entries.search(query) if query.present?

    case scope
    when "unread"
      entries = entries.where.not(id: current_user.user_entries.read.select(:entry_id))
    when "starred"
      entries = entries.where(id: current_user.user_entries.starred.select(:entry_id))
    end

    entries = entries.recent if query.blank?

    page = entries.limit(limit)
    user_entries_by_id = current_user.user_entries.where(entry_id: page.map(&:id)).index_by(&:entry_id)

    render json: { entries: page.map { |entry| serialize(entry, user_entries_by_id[entry.id]) } }
  end

  def show
    entry = current_user.subscribed_entries.includes(:feed).find(params[:id])
    user_entry = current_user.user_entries.find_by(entry: entry)

    render json: serialize_show(entry, user_entry)
  end

  private

  def serialize(entry, user_entry)
    {
      id: entry.id,
      title: entry.title,
      url: entry.url,
      published_at: entry.published_at&.iso8601,
      excerpt: entry.excerpt,
      read: user_entry&.read? || false,
      starred: user_entry&.starred? || false,
      feed: { id: entry.feed_id, title: entry.feed.display_title }
    }
  end

  def serialize_show(entry, user_entry)
    {
      id: entry.id,
      title: entry.title,
      url: entry.url,
      author: entry.author,
      published_at: entry.published_at&.iso8601,
      read: user_entry&.read? || false,
      starred: user_entry&.starred? || false,
      has_full_content: entry.full_content.present?,
      body: entry.plain_body,
      feed: { id: entry.feed_id, title: entry.feed.display_title }
    }
  end
end
