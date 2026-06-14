class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: :show
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to account_path, alert: "Try again later." }

  # Clicking the signed link verifies the account it was issued for, whether or
  # not the visitor happens to be signed in.
  def show
    if user = User.find_by_token_for(:email_verification, params[:token])
      user.verify!
      redirect_to after_verification_url, notice: "Your email has been verified."
    else
      redirect_to after_verification_url, alert: "That verification link is invalid or has expired."
    end
  end

  def create
    if Current.user.verified?
      redirect_to account_path, notice: "Your email is already verified."
    else
      EmailVerificationMailer.verify(Current.user).deliver_later
      redirect_to account_path, notice: "Verification email sent. Check your inbox."
    end
  end

  private
    def after_verification_url
      authenticated? ? account_path : new_session_path
    end
end
