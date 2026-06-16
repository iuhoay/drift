class SavedItems::BaseController < ApplicationController
  before_action :set_saved_item

  private

  def set_saved_item
    @saved_item = Current.user.saved_items.find(params[:saved_item_id])
  end

  def respond_with_turbo
    respond_to do |format|
      format.turbo_stream { render partial: "saved_items/actions_stream" }
      format.html { redirect_back fallback_location: saved_items_path }
    end
  end
end
