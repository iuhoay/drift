require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires a valid email_address" do
    user = User.new(password: "password")

    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"

    user.email_address = "not-an-email"
    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "rejects duplicate email_address regardless of case" do
    duplicate = User.new(email_address: "ONE@example.com", password: "password")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  test "enforces minimum password length" do
    user = User.new(email_address: "new@example.com", password: "short")

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "subscribed_entries returns entries from feeds the user subscribes to" do
    user = users(:one)

    assert_includes user.subscribed_entries, entries(:example_first)
    assert_includes user.subscribed_entries, entries(:stale_first)
    assert_not_includes user.subscribed_entries, entries(:unsubscribed_first)
  end

  test "destroys dependent records" do
    user = users(:one)

    assert_difference -> { Session.count } => -user.sessions.count,
                      -> { Subscription.count } => -user.subscriptions.count,
                      -> { UserEntry.count } => -user.user_entries.count do
      user.destroy
    end
  end

  test "destroys dependent identities" do
    user = users(:two)
    assert user.identities.any?

    assert_difference -> { Identity.count } => -user.identities.count do
      user.destroy
    end
  end

  test "verified? reflects verified_at" do
    assert users(:one).verified?
    assert_not users(:unverified).verified?
  end

  test "verify! sets verified_at once and is idempotent" do
    user = users(:unverified)

    user.verify!
    assert user.reload.verified?

    first = user.verified_at
    user.verify!
    assert_equal first, user.reload.verified_at
  end

  test "creating an already-verified user schedules one founder welcome email" do
    assert_enqueued_emails 1 do
      User.create!(email_address: "oauth@example.com", password: "password1", verified_at: Time.current)
    end
  end

  test "creating an unverified user schedules no welcome yet" do
    assert_no_enqueued_emails do
      User.create!(email_address: "pending@example.com", password: "password1")
    end
  end

  test "verifying for the first time schedules the founder welcome and stamps founder_welcomed_at" do
    user = users(:unverified)

    assert_enqueued_emails 1 do
      user.verify!
    end
    assert user.reload.founder_welcomed_at.present?
  end

  test "re-verifying after an email change does not welcome the user again" do
    user = users(:unverified)
    user.verify!
    user.update_column(:verified_at, nil) # account/emails un-verifies on email change

    assert_no_enqueued_emails do
      user.verify!
    end
  end

  test "email_verification token round-trips and is invalidated by an email change" do
    user = users(:one)
    token = user.generate_token_for(:email_verification)
    assert_equal user, User.find_by_token_for(:email_verification, token)

    user.update!(email_address: "changed@example.com")
    assert_nil User.find_by_token_for(:email_verification, token)
  end
end
