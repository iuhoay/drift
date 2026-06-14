class EmailVerificationMailer < ApplicationMailer
  def verify(user)
    @user = user
    @token = user.generate_token_for(:email_verification)
    mail subject: "Verify your email", to: user.email_address
  end
end
