class Entries::ReadsController < Entries::BaseController
  def create
    user_entry.mark_read!
    respond_with_turbo
  end

  def destroy
    user_entry.mark_unread!
    respond_with_turbo
  end
end
