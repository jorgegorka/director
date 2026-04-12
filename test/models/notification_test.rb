require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @user = users(:one)
    @role = roles(:cto)
    @budget_alert = notifications(:budget_alert_claude)
    @budget_exhausted = notifications(:budget_exhausted_http)
    @read_notification = notifications(:read_notification)
  end

  # --- Validations ---

  test "valid with project, recipient, and action" do
    notification = Notification.new(
      project: @project,
      recipient: @user,
      action: "budget_alert"
    )
    assert notification.valid?
  end

  test "invalid without action" do
    notification = Notification.new(
      project: @project,
      recipient: @user,
      action: nil
    )
    assert_not notification.valid?
    assert_includes notification.errors[:action], "can't be blank"
  end

  # --- Associations ---

  test "belongs to project via Tenantable" do
    assert_equal @project, @budget_alert.project
  end

  test "belongs to recipient (User)" do
    assert_equal @user, @budget_alert.recipient
  end

  test "belongs to actor (Role)" do
    assert_equal @role, @budget_alert.actor
  end

  test "belongs to notifiable (Role)" do
    assert_equal @role, @budget_alert.notifiable
  end

  test "actor is optional" do
    notification = Notification.new(
      project: @project,
      recipient: @user,
      action: "system_alert",
      actor: nil
    )
    assert notification.valid?
  end

  test "notifiable is optional" do
    notification = Notification.new(
      project: @project,
      recipient: @user,
      action: "system_alert",
      notifiable: nil
    )
    assert notification.valid?
  end

  # --- Scopes ---

  test "unread returns notifications without read_at" do
    unread = Notification.unread
    assert_includes unread, @budget_alert
    assert_not_includes unread, @budget_exhausted
  end

  test "read returns notifications with read_at" do
    read = Notification.read
    assert_includes read, @budget_exhausted
    assert_includes read, @read_notification
    assert_not_includes read, @budget_alert
  end

  test "recent returns up to 20 in reverse chronological order" do
    recent = Notification.recent
    assert recent.count <= 20
    if recent.count > 1
      assert recent.first.created_at >= recent.last.created_at
    end
  end

  test "for_current_project returns only notifications in Current.project" do
    Current.project = @project
    notifications = Notification.for_current_project
    notifications.each do |n|
      assert_equal @project, n.project
    end
  ensure
    Current.project = nil
  end

  # --- Methods ---

  test "read? returns true when read_at is set" do
    assert @budget_exhausted.read?
  end

  test "read? returns false when read_at is nil" do
    assert_not @budget_alert.read?
  end

  test "unread? returns true when read_at is nil" do
    assert @budget_alert.unread?
  end

  test "mark_as_read! sets read_at" do
    assert_nil @budget_alert.read_at
    @budget_alert.mark_as_read!
    assert @budget_alert.read_at.present?
    assert @budget_alert.read?
  end

  test "mark_as_read! does not update already-read notification" do
    original_read_at = @budget_exhausted.read_at
    @budget_exhausted.mark_as_read!
    assert_equal original_read_at, @budget_exhausted.read_at
  end

  test "metadata stores and retrieves hash data" do
    assert_kind_of Hash, @budget_alert.metadata
    assert_equal "CTO", @budget_alert.metadata["agent_name"]
  end

  # --- Deletion ---

  test "destroying project destroys notifications" do
    notification_count = @project.notifications.count
    assert notification_count > 0
    assert_difference "Notification.count", -notification_count do
      @project.destroy
    end
  end

  test "destroying user destroys recipient notifications" do
    user_notifications = Notification.where(recipient: @user)
    count = user_notifications.count
    assert count > 0
    # Remove invitations (foreign key constraint) before destroying user
    Invitation.where(inviter: @user).delete_all
    assert_difference "Notification.count", -count do
      @user.destroy
    end
  end

  # --- Role Notifiable ---

  test "role has many notifications as notifiable" do
    assert_includes @role.notifications, @budget_alert
  end

  test "destroying role destroys its notifiable notifications" do
    notif_count = @role.notifications.count
    assert notif_count > 0
    @role.created_tasks.update_all(creator_id: roles(:ceo).id)
    assert_difference "Notification.count", -notif_count do
      @role.destroy
    end
  end
end
