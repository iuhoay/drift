class SavedItems::ReadsController < SavedItems::BaseController
  def create
    @saved_item.mark_read!
    respond_with_turbo
  end

  def destroy
    @saved_item.mark_unread!
    respond_with_turbo
  end
end
