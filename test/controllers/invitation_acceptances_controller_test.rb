require "test_helper"

class InvitationAcceptancesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = invitations(:pending_invite)
  end

  test "shows acceptance page for valid invitation" do
    get invitation_acceptance_url(token: @invitation.token)
    assert_response :success
    assert_select "h1", /Join.*Acme AI Corp/
  end

  test "redirects for expired invitation" do
    expired = invitations(:expired_invite)
    get invitation_acceptance_url(token: expired.token)
    assert_redirected_to root_url
  end

  test "redirects for invalid token" do
    get invitation_acceptance_url(token: "nonexistent")
    assert_redirected_to root_url
  end

  test "logged-in user can accept invitation" do
    new_user = User.create!(email_address: "invitee@example.com", password: "password", password_confirmation: "password")
    sign_in_as(new_user)

    assert_difference("Membership.count", 1) do
      patch invitation_acceptance_url(token: @invitation.token)
    end

    @invitation.reload
    assert @invitation.accepted?
    assert_redirected_to root_url
  end

  test "new user can create account and accept" do
    assert_difference([ "User.count", "Membership.count" ], 1) do
      patch invitation_acceptance_url(token: @invitation.token), params: {
        user: {
          email_address: "invitee@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    @invitation.reload
    assert @invitation.accepted?
    assert_redirected_to root_url
  end

  test "existing user without session is redirected to login" do
    # Create user with the invited email but don't sign in
    User.create!(email_address: "invitee@example.com", password: "password", password_confirmation: "password")

    patch invitation_acceptance_url(token: @invitation.token)
    assert_redirected_to new_session_url
  end

  test "cannot accept already accepted invitation" do
    accepted = invitations(:accepted_invite)
    new_user = User.create!(email_address: "another@example.com", password: "password", password_confirmation: "password")
    sign_in_as(new_user)

    assert_no_difference("Membership.count") do
      patch invitation_acceptance_url(token: accepted.token)
    end
    assert_redirected_to root_url
  end

  test "cannot accept expired invitation" do
    expired = invitations(:expired_invite)
    new_user = User.create!(email_address: "expired@example.com", password: "password", password_confirmation: "password")
    sign_in_as(new_user)

    assert_no_difference("Membership.count") do
      patch invitation_acceptance_url(token: expired.token)
    end
    assert_redirected_to root_url
  end

  test "accepted invitation sets project in session" do
    new_user = User.create!(email_address: "invitee@example.com", password: "password", password_confirmation: "password")
    sign_in_as(new_user)

    patch invitation_acceptance_url(token: @invitation.token)
    follow_redirect! # root → pages#home redirects authenticated users to dashboard
    follow_redirect!
    assert_response :success
    # Should show the project name from the invitation
    assert_select "h1", "Acme AI Corp"
  end
end
