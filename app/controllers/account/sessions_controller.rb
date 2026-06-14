class Account::SessionsController < ApplicationController
  def index
    @sessions = Current.user.sessions.order(Arel.sql("COALESCE(last_active_at, created_at) DESC"))
  end

  def destroy
    session = Current.user.sessions.find(params[:id])
    signing_out_self = session.id == Current.session&.id
    session.destroy

    if signing_out_self
      cookies.delete(:session_id)
      Current.session = nil
      redirect_to new_session_path, notice: "Signed out.", status: :see_other
    else
      redirect_to account_sessions_path, notice: "That device has been signed out.", status: :see_other
    end
  end

  def destroy_others
    Current.user.sessions.where.not(id: Current.session.id).destroy_all
    redirect_to account_sessions_path, notice: "Signed out of all other devices.", status: :see_other
  end
end
