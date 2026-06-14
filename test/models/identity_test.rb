require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "requires provider and uid" do
    identity = Identity.new(user: users(:one))

    assert_not identity.valid?
    assert_includes identity.errors[:provider], "can't be blank"
    assert_includes identity.errors[:uid], "can't be blank"
  end

  test "uid is unique per provider" do
    existing = identities(:two_github)
    duplicate = Identity.new(user: users(:one), provider: existing.provider, uid: existing.uid)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uid], "has already been taken"
  end

  test "the same uid may exist for different providers" do
    existing = identities(:two_github)
    other = Identity.new(user: users(:one), provider: "google_oauth2", uid: existing.uid)

    assert other.valid?
  end

  test "label_for maps known providers" do
    assert_equal "GitHub", Identity.label_for("github")
    assert_equal "Google", Identity.label_for("google_oauth2")
  end

  test "configured_providers is empty without credentials" do
    assert_empty Identity.configured_providers
  end
end
