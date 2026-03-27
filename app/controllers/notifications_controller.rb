class NotificationsController < ApplicationController
  before_action :require_company!

  def index
    @notifications = Current.company.notifications
                      .where(recipient: Current.user)
                      .recent
                      .includes(:notifiable, :actor)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def mark_read
    notification = Current.company.notifications
                    .where(recipient: Current.user)
                    .find(params[:id])
    notification.mark_as_read!

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          dom_id(notification),
          partial: "notifications/notification",
          locals: { notification: notification }
        )
      }
    end
  end

  def mark_all_read
    Current.company.notifications
      .where(recipient: Current.user)
      .unread
      .update_all(read_at: Time.current)

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream {
        render turbo_stream: turbo_stream.update("notification-badge", html: "")
      }
    end
  end
end
