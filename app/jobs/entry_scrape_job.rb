class EntryScrapeJob < ApplicationJob
  include ActionView::RecordIdentifier

  queue_as :default

  def perform(entry_id)
    entry = Entry.find_by(id: entry_id)
    return unless entry

    Entry::Scraper.call(entry)
    broadcast_result(entry)
  end

  private

  # The reader who clicked "load full text" has already left the request
  # cycle, so the outcome goes back to the entry page over the entry's Turbo
  # Stream. The stream is entry-scoped on purpose: entries are shared across
  # subscribers, so one reader's fetch fills the page for everyone on it.
  def broadcast_result(entry)
    if entry.full_content.present?
      Turbo::StreamsChannel.broadcast_replace_to entry,
        target: dom_id(entry, :body),
        partial: "entries/body", locals: { entry: entry }
      Turbo::StreamsChannel.broadcast_remove_to entry,
        target: dom_id(entry, :full_content_request)
    else
      Turbo::StreamsChannel.broadcast_replace_to entry,
        target: dom_id(entry, :full_content_request),
        partial: "entries/full_content_failed", locals: { entry: entry }
    end
  end
end
