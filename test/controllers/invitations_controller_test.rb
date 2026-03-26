require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @member = users(:two)
    @company = companies(:acme)
    sign_in_as(@owner)
    # Ensure session has the right company
    post company_switch_url(@company)
  end

  test "owner can view invitations index" do
    get invitations_url
    assert_response :success
  end

  test "member cannot view invitations" do
    sign_in_as(@member)
    post company_switch_url(@company)
    get invitations_url
    assert_redirected_to root_url
  end

  test "owner can view new invitation form" do
    get new_invitation_url
    assert_response :success
    assert_select "form"
  end

  test "owner can invite as member" do
    assert_difference("Invitation.count", 1) do
      post invitations_url, params: {
        invitation: { email_address: "new@example.com", role: "member" }
      }
    end
    assert_redirected_to invitations_url
    invitation = Invitation.order(:created_at).last
    assert invitation.member?
    assert_equal @owner, invitation.inviter
  end

  test "owner can invite as admin" do
    assert_difference("Invitation.count", 1) do
      post invitations_url, params: {
        invitation: { email_address: "newadmin@example.com", role: "admin" }
      }
    end
    invitation = Invitation.order(:created_at).last
    assert invitation.admin?
  end

  test "admin can invite as member" do
    # user :one is admin of :widgets
    sign_in_as(@owner)
    post company_switch_url(companies(:widgets))
    assert_difference("Invitation.count", 1) do
      post invitations_url, params: {
        invitation: { email_address: "widgets_new@example.com", role: "member" }
      }
    end
  end

  test "admin cannot invite as admin" do
    sign_in_as(@owner)
    post company_switch_url(companies(:widgets))
    assert_no_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: { email_address: "widgets_admin@example.com", role: "admin" }
      }
    end
  end

  test "sends invitation email" do
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post invitations_url, params: {
        invitation: { email_address: "emailed@example.com", role: "member" }
      }
    end
  end

  test "does not create invitation with blank email" do
    assert_no_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: { email_address: "", role: "member" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "does not create invitation for existing member" do
    assert_no_difference("Invitation.count") do
      post invitations_url, params: {
        invitation: { email_address: "two@example.com", role: "member" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "redirects unauthenticated user" do
    sign_out
    get invitations_url
    assert_redirected_to new_session_url
  end
end
