require "test_helper"

class Tools::ReviewTaskAgentTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @task = tasks(:fix_login_bug)
    # cto created fix_login_bug; flip to pending_review so the review can approve.
    @task.update_columns(status: Task.statuses[:pending_review])
    @goal = @task.goal

    # Give cto a running role_run so resolve_parent_role_run finds one.
    @role_run = role_runs(:completed_run)
    @role_run.update_columns(role_id: @role.id, status: RoleRun.statuses[:running])
  end

  # Build a ReviewTaskAgent whose super#call (the review sub-agent spawn) is
  # stubbed out. The review sub-agent marks the task as completed in the real
  # flow, so we do it in setup instead. We also intercept SummarizeGoal.new
  # to detect whether auto-summarization fires.
  def build_tool(summarize_spy:)
    tool = Tools::ReviewTaskAgent.new(@role)

    # Stub SubAgentTool#call (super) — the review sub-agent would normally
    # spawn a claude -p process; we return a canned success response.
    review_result = { status: "ok", sub_agent: "review_task", summary: "Approved.", cost_cents: 1 }
    original_call = tool.method(:call)

    # We can't stub `super` directly, so we override the sub_agent_class to
    # return a fake sub-agent that produces canned output.
    fake_sub_agent = Object.new
    fake_sub_agent.define_singleton_method(:call) { review_result }

    original_new = SubAgents::ReviewTask.method(:new)
    SubAgents::ReviewTask.define_singleton_method(:new) { |**_kwargs| fake_sub_agent }

    # Intercept SummarizeGoal.new to track whether it's called.
    summarize_result = { status: "ok", summary: "Goal summarized." }
    original_summarize_new = SubAgents::SummarizeGoal.method(:new)
    SubAgents::SummarizeGoal.define_singleton_method(:new) do |**kwargs|
      summarize_spy[:called] = true
      summarize_spy[:arguments] = kwargs[:arguments]
      fake = Object.new
      fake.define_singleton_method(:call) { summarize_result }
      fake
    end

    # Return the tool and a cleanup proc.
    cleanup = -> {
      SubAgents::ReviewTask.define_singleton_method(:new, original_new)
      SubAgents::SummarizeGoal.define_singleton_method(:new, original_summarize_new)
    }

    [ tool, cleanup ]
  end

  test "auto-summarizes goal when approval completes all tasks" do
    @goal.tasks.where.not(id: @task.id).update_all(status: Task.statuses[:completed])
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    assert spy[:called], "SummarizeGoal sub-agent should have been triggered"
    assert_equal @goal.id, spy[:arguments]["goal_id"]
  end

  test "does not auto-summarize when goal has remaining incomplete tasks" do
    assert @goal.tasks.where.not(id: @task.id).where.not(status: :completed).exists?
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    refute spy[:called], "SummarizeGoal should not be triggered when goal is incomplete"
  end

  test "does not auto-summarize when goal already has a summary" do
    @goal.tasks.where.not(id: @task.id).update_all(status: Task.statuses[:completed])
    @task.update_columns(status: Task.statuses[:completed])
    @goal.update_columns(summary: "Already summarized.")

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    refute spy[:called], "SummarizeGoal should not be triggered when summary already exists"
  end

  test "does not auto-summarize when task has no goal" do
    @task.update_columns(goal_id: nil, status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    refute spy[:called], "SummarizeGoal should not be triggered for tasks without a goal"
  end

  test "includes goal_summarized in result when summarization happens" do
    @goal.tasks.where.not(id: @task.id).update_all(status: Task.statuses[:completed])
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      result = tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    assert_equal @goal.id, result[:goal_summarized]
  end

  test "does not include goal_summarized when no summarization needed" do
    @task.update_columns(status: Task.statuses[:completed])

    spy = {}
    tool, cleanup = build_tool(summarize_spy: spy)
    begin
      result = tool.call({ "task_id" => @task.id.to_s })
    ensure
      cleanup.call
    end

    assert_nil result[:goal_summarized]
  end
end
