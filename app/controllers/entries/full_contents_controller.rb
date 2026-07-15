class Entries::FullContentsController < Entries::BaseController
  # The fetch happens in the background: EntryScrapeJob broadcasts the scraped
  # body (or a failure note) back to the page over the entry's Turbo Stream.
  def create
    EntryScrapeJob.perform_later(@entry.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to entry_path(@entry), status: :see_other, notice: "Fetching full text — reload in a moment." }
    end
  end
end
