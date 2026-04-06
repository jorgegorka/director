class InvitationAcceptancesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_invitation

  def show
    if @invitation.nil?
      redirect_to root_path, alert: "Invitation not found."
    elsif !@invitation.acceptable?
      redirect_to root_path, alert: "This invitation has expired or already been accepted."
    end
  end

  def update
    if @invitation.nil? || !@invitation.acceptable?
      redirect_to root_path, alert: "This invitation is no longer valid."
      return
    end

    if authenticated?
      # Existing user who is logged in -- accept directly
      accept_invitation(Current.user)
    else
      # Check if a user with this email already exists
      existing_user = User.find_by(email_address: @invitation.email_address)
      if existing_user
        # Redirect to login with return URL to this acceptance
        session[:return_to_after_authenticating] = invitation_acceptance_path(token: @invitation.token)
        redirect_to new_session_path, notice: "Please log in to accept this invitation."
      else
        # Create new account and accept
        @user = User.new(user_params)
        if @user.save
          start_new_session_for(@user)
          accept_invitation(@user)
        else
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_invitation
    @invitation = Invitation.find_by(token: params[:token])
  end

  def accept_invitation(user)
    @invitation.accept!(user)
    session[:project_id] = @invitation.project_id
    redirect_to root_path, notice: "Welcome to #{@invitation.project.name}!"
  end

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
