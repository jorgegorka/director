require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:design_homepage)
    @user = users(:one)
    @role = roles(:cto)
    @message = messages(:first_update)
  end

  # --- Validations ---

  test "valid with body, task, and author" do
    message = Message.new(body: "Hello", task: @task, author: @user)
    assert message.valid?
  end

  test "invalid without body" do
    message = Message.new(body: nil, task: @task, author: @user)
    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "valid with User author" do
    message = Message.new(body: "User message", task: @task, author: @user)
    assert message.valid?
  end

  test "valid with Role author" do
    message = Message.new(body: "Role message", task: @task, author: @role)
    assert message.valid?
  end

  test "valid without parent (root message)" do
    message = Message.new(body: "Root message", task: @task, author: @user)
    assert message.valid?
    assert_nil message.parent
  end

  test "invalid when parent belongs to different task" do
    other_task = tasks(:fix_login_bug)
    other_message = messages(:bug_report_msg)
    reply = Message.new(body: "Bad reply", task: @task, author: @user, parent: other_message)
    assert_not reply.valid?
    assert_includes reply.errors[:parent], "must belong to the same task"
  end

  # --- Associations ---

  test "belongs to task" do
    assert_equal @task, @message.task
  end

  test "belongs to author (polymorphic) - User" do
    assert_equal @user, @message.author
    assert_equal "User", @message.author_type
  end

  test "belongs to author (polymorphic) - Role" do
    role_message = messages(:agent_reply)
    assert_equal @role, role_message.author
    assert_equal "Role", role_message.author_type
  end

  test "belongs to parent (optional)" do
    reply = messages(:threaded_reply)
    assert_equal messages(:agent_reply), reply.parent
  end

  test "has many replies" do
    parent_message = messages(:agent_reply)
    assert_includes parent_message.replies, messages(:threaded_reply)
  end

  # --- Scopes ---

  test "roots returns only messages without parent" do
    roots = Message.roots
    assert_includes roots, @message
    assert_not_includes roots, messages(:threaded_reply)
  end

  test "chronological returns oldest first" do
    task_messages = Message.where(task: @task).chronological
    # First message should have the earliest created_at
    assert task_messages.first.created_at <= task_messages.last.created_at
  end

  # --- Threading ---

  test "reply has parent set" do
    reply = messages(:threaded_reply)
    assert_not_nil reply.parent
    assert_equal messages(:agent_reply), reply.parent
  end

  test "parent replies include the reply" do
    parent = messages(:agent_reply)
    reply = messages(:threaded_reply)
    assert_includes parent.replies, reply
  end

  test "nested replies work (reply to a reply)" do
    parent = messages(:agent_reply)
    reply = messages(:threaded_reply)
    nested = Message.create!(body: "Nested reply", task: @task, author: @role, parent: reply)
    assert_equal reply, nested.parent
    assert_includes reply.replies, nested
  end
end
