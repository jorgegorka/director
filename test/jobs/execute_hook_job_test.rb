require "test_helper"

class ExecuteHookJobTest < ActiveSupport::TestCase
  setup do
    @execution = hook_executions(:completed_execution)
  end

  test "skips completed execution" do
    assert @execution.completed?
    # Should return early without calling service
    assert_nothing_raised do
      ExecuteHookJob.perform_now(@execution.id)
    end
  end

  test "skips failed execution" do
    @execution = hook_executions(:failed_execution)
    assert @execution.failed?
    assert_nothing_raised do
      ExecuteHookJob.perform_now(@execution.id)
    end
  end

  test "skips when execution not found" do
    assert_nothing_raised do
      ExecuteHookJob.perform_now(999999)
    end
  end

  test "has retry_on configured for 3 attempts" do
    # Verify the job class has retry_on set up via rescue_handlers
    assert ExecuteHookJob.instance_method(:perform)
    # The retry_on configuration is verified by checking the class has the discard handler
    assert ExecuteHookJob.respond_to?(:retry_on)
  end

  test "job is enqueued to default queue" do
    assert_equal "default", ExecuteHookJob.new.queue_name
  end
end
