class Api::Entries::ReadsController < Api::BaseController
  before_action :set_entry

  def create
    user_entry.mark_read!
    render json: read_payload
  end

  def destroy
    user_entry.mark_unread!
    render json: read_payload
  end

  private

  def set_entry
    @entry = current_user.subscribed_entries.find(params[:entry_id])
  end

  def user_entry
    @user_entry ||= current_user.user_entries.find_or_create_by!(entry: @entry)
  end

  def read_payload
    {
      id: @entry.id,
      read: user_entry.read?,
      read_at: user_entry.read_at&.iso8601
    }
  end
end
