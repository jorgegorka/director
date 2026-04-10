class SettingsController < ApplicationController
  before_action :set_user

  def show
  end

  def update
    unless @user.authenticate(params[:current_password])
      @user.errors.add(:base, "Current password is incorrect")
      return render :show, status: :unprocessable_entity
    end

    if @user.update(settings_params)
      redirect_to settings_path, notice: "Account settings updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def settings_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
