class Entries::StarsController < Entries::BaseController
  def create
    user_entry.mark_starred!
    respond_with_turbo
  end

  def destroy
    user_entry.mark_unstarred!
    respond_with_turbo
  end
end
