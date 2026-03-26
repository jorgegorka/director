require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @inviter = users(:one)
  end

  test "valid invitation" do
    invitation = Invitation.new(
      company: @company,
      inviter: @inviter,
      email_address: "new@example.com",
      role: :member
    )
    assert invitation.valid?
  end

  test "generates token on create" do
    invitation = Invitation.create!(
      company: @company,
      inviter: @inviter,
      email_address: "token@example.com",
      role: :member
    )
    assert_not_nil invitation.token
    assert_equal 43, invitation.token.length  # base64 of 32 bytes
  end

  test "sets expiration on create" do
    invitation = Invitation.create!(
      company: @company,
      inviter: @inviter,
      email_address: "expires@example.com",
      role: :member
    )
    assert_in_delta 30.days.from_now, invitation.expires_at, 5.seconds
  end

  test "normalizes email address" do
    invitation = Invitation.new(email_address: " Test@Example.COM ")
    assert_equal "test@example.com", invitation.email_address
  end

  test "invalid without email" do
    invitation = Invitation.new(company: @company, inviter: @inviter, role: :member, email_address: nil)
    assert_not invitation.valid?
  end

  test "invalid with malformed email" do
    invitation = Invitation.new(company: @company, inviter: @inviter, role: :member, email_address: "not-an-email")
    assert_not invitation.valid?
  end

  test "prevents inviting existing member" do
    # user :two is already a member of :acme via fixtures
    invitation = Invitation.new(
      company: @company,
      inviter: @inviter,
      email_address: "two@example.com",
      role: :member
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:email_address], "is already a member of this company"
  end

  test "acceptable when pending and not expired" do
    assert invitations(:pending_invite).acceptable?
  end

  test "not acceptable when expired" do
    assert_not invitations(:expired_invite).acceptable?
  end

  test "not acceptable when already accepted" do
    assert_not invitations(:accepted_invite).acceptable?
  end

  test "accept! creates membership and updates status" do
    invitation = invitations(:pending_invite)
    new_user = User.create!(email_address: "invitee@example.com", password: "password", password_confirmation: "password")

    assert_difference("Membership.count", 1) do
      invitation.accept!(new_user)
    end

    invitation.reload
    assert invitation.accepted?
    assert_not_nil invitation.accepted_at
    assert @company.memberships.exists?(user: new_user, role: :member)
  end

  test "role enum has member and admin only" do
    assert_equal({ "member" => 0, "admin" => 1 }, Invitation.roles)
  end

  test "active scope returns only pending non-expired invitations" do
    active = Invitation.active.where(company: @company)
    assert_includes active, invitations(:pending_invite)
    assert_not_includes active, invitations(:expired_invite)
    assert_not_includes active, invitations(:accepted_invite)
  end
end
