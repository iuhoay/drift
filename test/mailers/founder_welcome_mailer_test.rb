require "test_helper"

class FounderWelcomeMailerTest < ActionMailer::TestCase
  test "welcome comes from the founder and replies route back to them" do
    mail = FounderWelcomeMailer.welcome(users(:one))

    assert_equal [ users(:one).email_address ], mail.to
    assert_equal [ FounderWelcomeMailer::FROM_ADDRESS ], mail.from
    assert_equal [ FounderWelcomeMailer::FROM_ADDRESS ], mail.reply_to
    assert_equal "Thanks for trying Drift", mail.subject
    assert_match "Jack", mail.body.encoded
  end

  test "welcome is plain text only, no HTML part" do
    mail = FounderWelcomeMailer.welcome(users(:one))

    assert_equal "text/plain", mail.mime_type
    assert_nil mail.html_part
  end

  test "does not send to an unverified address" do
    assert_no_emails do
      FounderWelcomeMailer.welcome(users(:unverified)).deliver_now
    end
  end
end
