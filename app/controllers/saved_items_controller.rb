class SavedItemsController < ApplicationController
  before_action :set_saved_item, only: [ :show, :destroy ]

  PER_PAGE = 50

  def index
    @scope = params[:scope].presence_in(%w[all unread starred]) || "unread"
    @query = params[:q].to_s.strip

    items = Current.user.saved_items
    items = items.search(@query) if @query.present?

    case @scope
    when "unread"  then items = items.unread
    when "starred" then items = items.starred
    end

    items = items.recent if @query.blank?
    @saved_items = items.limit(PER_PAGE)
  end

  def show
    # Like EntriesController#show, kept a safe GET: marking read happens via a
    # POST to SavedItems::ReadsController once the page actually renders.
  end

  def create
    url = params.dig(:saved_item, :url).to_s.strip
    @saved_item = Current.user.saved_items.find_or_initialize_by(url: url)

    if @saved_item.persisted?
      redirect_to saved_items_path, notice: "Already saved."
    elsif @saved_item.save
      SavedItemFetchJob.perform_later(@saved_item.id)
      redirect_to saved_items_path, notice: "Saved — fetching details."
    else
      redirect_to saved_items_path, alert: @saved_item.errors.full_messages.to_sentence
    end
  end

  def destroy
    @saved_item.destroy
    redirect_to saved_items_path, notice: "Removed.", status: :see_other
  end

  private

  def set_saved_item
    @saved_item = Current.user.saved_items.find(params[:id])
  end
end
