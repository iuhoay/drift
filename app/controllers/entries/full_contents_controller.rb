class Entries::FullContentsController < Entries::BaseController
  # Synchronous on purpose: the reader is waiting on the page for the article
  # body, and Feed.http_connection bounds how long the fetch may hang.
  def create
    Entry::Scraper.call(@entry)

    if @entry.full_content.present?
      redirect_to entry_path(@entry), status: :see_other
    else
      redirect_to entry_path(@entry), status: :see_other,
        alert: "Couldn't extract a readable copy — try the original instead."
    end
  end
end
