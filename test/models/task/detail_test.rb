require "test_helper"

class Task::DetailTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:design_homepage)
    @detail = Task::Detail.new(@task)
  end

  test "exposes the task" do
    assert_equal @task, @detail.task
  end

  # --- messages ---

  test "messages returns root messages in chronological order" do
    messages = @detail.messages
    assert messages.all? { |m| m.parent_id.nil? }
    assert_equal messages.sort_by(&:created_at), messages.to_a
  end

  test "messages eager loads authors and replies" do
    @detail.messages.each do |message|
      assert message.association(:author).loaded?
      assert message.association(:replies).loaded?
    end
  end

  test "messages is memoized" do
    assert_same @detail.messages, @detail.messages
  end

  # --- audit_events ---

  test "audit_events returns task audit events" do
    events = @detail.audit_events
    assert events.any?
    assert events.all? { |e| e.auditable == @task }
  end

  test "audit_events eager loads actor" do
    @detail.audit_events.each do |event|
      assert event.association(:actor).loaded?
    end
  end

  test "audit_events is memoized" do
    assert_same @detail.audit_events, @detail.audit_events
  end

  # --- new_message ---

  test "new_message returns a new Message instance" do
    assert_instance_of Message, @detail.new_message
    assert @detail.new_message.new_record?
  end

  test "new_message is memoized" do
    assert_same @detail.new_message, @detail.new_message
  end

  # --- document_links ---

  test "document_links returns task documents ordered by document title" do
    links = @detail.document_links
    assert links.any?
    titles = links.map { |td| td.document.title }
    assert_equal titles.sort, titles
  end

  test "document_links eager loads documents" do
    @detail.document_links.each do |td|
      assert td.association(:document).loaded?
    end
  end

  test "document_links is memoized" do
    assert_same @detail.document_links, @detail.document_links
  end

  # --- task_evaluations ---

  test "task_evaluations returns evaluations ordered by attempt number" do
    detail = Task::Detail.new(tasks(:eval_ready_task))
    evals = detail.task_evaluations
    assert evals.any?
    assert_equal evals.sort_by(&:attempt_number), evals.to_a
  end

  test "task_evaluations eager loads root_task" do
    detail = Task::Detail.new(tasks(:eval_ready_task))
    detail.task_evaluations.each do |eval|
      assert eval.association(:root_task).loaded?
    end
  end

  test "task_evaluations is memoized" do
    assert_same @detail.task_evaluations, @detail.task_evaluations
  end

  # --- boolean helpers ---

  test "any_messages? returns true when messages exist" do
    assert @detail.any_messages?
  end

  test "any_messages? returns false when no messages" do
    detail = Task::Detail.new(tasks(:write_tests))
    assert_not detail.any_messages?
  end

  test "any_documents? returns true when documents exist" do
    assert @detail.any_documents?
  end

  test "any_documents? returns false when no documents" do
    detail = Task::Detail.new(tasks(:fix_login_bug))
    assert_not detail.any_documents?
  end

  test "any_evaluations? returns true when evaluations exist" do
    detail = Task::Detail.new(tasks(:eval_ready_task))
    assert detail.any_evaluations?
  end

  test "any_evaluations? returns false when no evaluations" do
    assert_not @detail.any_evaluations?
  end
end
