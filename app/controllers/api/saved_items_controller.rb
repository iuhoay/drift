class Api::SavedItemsController < Api::BaseController
  # POST /api/saved_items  { url:, title? }
  #
  # Idempotent per user: saving a URL already in the list returns the existing
  # record (200) instead of erroring on the uniqueness constraint. A brand-new
  # save stores the tab title immediately so the item is useful before the
  # enrichment job runs, then enqueues SavedItemFetchJob to fill the rest.
  def create
    item = current_user.saved_items.find_or_initialize_by(url: params[:url].to_s.strip)

    if item.persisted?
      return render json: serialize(item), status: :ok
    end

    item.title = params[:title].to_s.strip.presence

    if item.save
      SavedItemFetchJob.perform_later(item.id)
      render json: serialize(item), status: :created
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def serialize(item)
    { id: item.id, url: item.url, title: item.display_title, saved_at: item.saved_at }
  end
end
