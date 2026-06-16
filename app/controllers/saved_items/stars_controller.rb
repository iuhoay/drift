class SavedItems::StarsController < SavedItems::BaseController
  def create
    @saved_item.mark_starred!
    respond_with_turbo
  end

  def destroy
    @saved_item.mark_unstarred!
    respond_with_turbo
  end
end
