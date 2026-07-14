# Fetches the page behind an entry's URL and stores a readable copy in
# `full_content`, for feeds that truncate or omit the article body (digests,
# title-only feeds). Triggered by a reader from the entry page; entries are
# shared across subscribers, so one reader's fetch fills the entry for everyone.
#
# Mirrors SavedItem::Fetcher: fetches through Feed.http_connection so it
# inherits the SSRF guard, User-Agent, redirect limit, and timeouts, and `http`
# is injectable for tests. A failed fetch or extraction leaves the entry
# untouched — in particular it never clears a previously fetched copy.
class Entry::Scraper
  def self.call(entry)
    new(entry).call
  end

  def initialize(entry, http: nil)
    @entry = entry
    @http = http
  end

  def call
    return @entry if @entry.safe_url.blank?

    response = http.get(@entry.url)
    return @entry unless response.status.in?(200..299)

    content = ArticleExtractor.extract(response.body, @entry.url)
    @entry.update!(full_content: content) if content
    @entry
  rescue Faraday::Error
    @entry
  end

  private

  def http
    @http ||= Feed.http_connection
  end
end
