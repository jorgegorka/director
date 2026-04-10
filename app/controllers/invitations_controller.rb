class InvitationsController < ApplicationController
  before_action :require_project!
  before_action :authorize_inviter!

  def index
    @invitations = Current.project.invitations.active.order(created_at: :desc)
    @memberships = Current.project.memberships.includes(:user).order(:role)
  end

  def new
    @invitation = Current.project.invitations.new
  end

  def create
    @invitation = Current.project.invitations.new(invitation_params)
    @invitation.inviter = Current.user

    if @invitation.save
      InvitationMailer.invite(@invitation).deliver_later
      redirect_to invitations_path, notice: "Invitation sent to #{@invitation.email_address}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def invitation_params
    params.require(:invitation).permit(:email_address, :role)
  end

  def authorize_inviter!
    membership = Current.project.memberships.find_by(user: Current.user)

    unless membership&.owner? || membership&.admin?
      redirect_to root_path, alert: "You don't have permission to manage invitations."
      return
    end

    # Admin can only invite members, not other admins
    if membership.admin? && invitation_params_role == "admin"
      redirect_to new_invitation_path, alert: "Only the project owner can invite admins."
    end
  end

  def invitation_params_role
    params.dig(:invitation, :role)
  end
end
