require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @task = tasks(:design_homepage)
    @widgets_task = tasks(:widgets_task)
    @first_update = messages(:first_update)
  end

  # --- Create ---

  test "should create message" do
    assert_difference("Message.count", 1) do
      post task_messages_url(@task), params: {
        message: { body: "This is a new message." }
      }
    end
    message = Message.order(:created_at).last
    assert_equal "This is a new message.", message.body
    assert_redirected_to task_url(@task, anchor: "message_#{message.id}")
  end

  test "message author is current user" do
    post task_messages_url(@task), params: {
      message: { body: "Authored message." }
    }
    message = Message.order(:created_at).last
    assert_equal @user, message.author
    assert_equal "User", message.author_type
    assert_equal @user.id, message.author_id
  end

  test "should create reply message" do
    assert_difference("Message.count", 1) do
      post task_messages_url(@task), params: {
        message: { body: "This is a reply.", parent_id: @first_update.id }
      }
    end
    reply = Message.order(:created_at).last
    assert_equal @first_update, reply.parent
    assert_equal @task, reply.task
  end

  test "should not create message with blank body" do
    assert_no_difference("Message.count") do
      post task_messages_url(@task), params: {
        message: { body: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create message on task from another project" do
    assert_no_difference("Message.count") do
      post task_messages_url(@widgets_task), params: {
        message: { body: "Cross-project message." }
      }
    end
    assert_redirected_to root_url
  end

  # --- Auth ---

  test "should redirect unauthenticated user" do
    sign_out
    post task_messages_url(@task), params: {
      message: { body: "Unauthorized message." }
    }
    assert_redirected_to new_session_url
  end
end
