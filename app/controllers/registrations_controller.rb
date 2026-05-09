class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for(@user)
      redirect_to after_authentication_url, notice: "Welcome to Drift."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: [ :email_address, :password, :password_confirmation ])
  end

  def start_new_session_for(user)
    session_record = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
    Current.session = session_record
    cookies.signed.permanent[:session_id] = { value: session_record.id, httponly: true, same_site: :lax }
  end
end
