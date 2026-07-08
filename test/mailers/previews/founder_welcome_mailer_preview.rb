# Preview all emails at http://localhost:3000/rails/mailers/founder_welcome_mailer
class FounderWelcomeMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/founder_welcome_mailer/welcome
  def welcome
    FounderWelcomeMailer.welcome(User.where.not(verified_at: nil).take)
  end
end
