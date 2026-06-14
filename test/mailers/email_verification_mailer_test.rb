require "test_helper"

class EmailVerificationMailerTest < ActionMailer::TestCase
  test "verify is addressed to the user and carries a working token link" do
    user = users(:unverified)
    mail = EmailVerificationMailer.verify(user)

    assert_equal [ user.email_address ], mail.to
    assert_equal "Verify your email", mail.subject

    token = mail.body.encoded[%r{/email_verifications/([^"\s]+)}, 1]
    assert token.present?, "expected a verification token in the email body"
    assert_equal user, User.find_by_token_for(:email_verification, token)
  end
end
