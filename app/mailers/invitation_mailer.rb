class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @accept_url = invitation_acceptance_url(token: @invitation.token)
    @company = invitation.company
    @inviter = invitation.inviter

    mail(
      to: @invitation.email_address,
      subject: "You've been invited to join #{@company.name} on Director"
    )
  end
end
