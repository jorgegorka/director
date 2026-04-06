require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "unread_notification_count returns count of unread notifications" do
    user = users(:one)
    count = user.unread_notification_count
    assert count >= 0
  end

  test "unread_notification_count scoped to project" do
    user = users(:one)
    project = projects(:acme)
    count = user.unread_notification_count(project: project)
    assert count >= 0
  end
end
