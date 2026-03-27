require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @notification = notifications(:budget_alert_claude)
  end

  test "should get index" do
    get notifications_url
    assert_response :success
  end

  test "should mark notification as read" do
    assert_nil @notification.read_at
    patch mark_read_notification_url(@notification)
    @notification.reload
    assert @notification.read_at.present?
  end

  test "should mark all notifications as read" do
    assert Notification.where(recipient: @user, company: @company).unread.count > 0
    post mark_all_read_notifications_url
    assert_equal 0, Notification.where(recipient: @user, company: @company).unread.count
  end

  test "should not mark notification from another company" do
    widgets_notification = Notification.create!(
      company: companies(:widgets),
      recipient: @user,
      action: "test_alert"
    )
    patch mark_read_notification_url(widgets_notification)
    assert_response :not_found
  end

  test "header shows notification bell when company selected" do
    get root_url
    assert_response :success
    assert_select ".notification-dropdown__trigger"
  end

  test "header shows badge count for unread notifications" do
    get root_url
    assert_response :success
    assert_select ".notification-dropdown__badge"
  end

  test "requires authentication" do
    sign_out
    get notifications_url
    assert_response :redirect
  end
end
