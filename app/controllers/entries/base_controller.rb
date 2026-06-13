class Entries::BaseController < ApplicationController
  before_action :set_entry

  private

  def set_entry
    @entry = Current.user.subscribed_entries.find(params[:entry_id])
  end

  def user_entry
    @user_entry ||= Current.user.user_entries.find_or_create_by!(entry: @entry)
  end

  def respond_with_turbo
    respond_to do |format|
      format.turbo_stream { render partial: "entries/actions_stream" }
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
