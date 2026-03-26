require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  test "invite email" do
    invitation = invitations(:pending_invite)
    email = InvitationMailer.invite(invitation)

    assert_equal [ "invitee@example.com" ], email.to
    assert_match "invited to join", email.subject
    assert_match "Acme AI Corp", email.subject
    assert_match invitation.token, email.body.encoded
  end
end
