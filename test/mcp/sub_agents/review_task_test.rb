require "test_helper"

class SubAgents::ReviewTaskTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @role_run = role_runs(:running_run)
    @task = tasks(:fix_login_bug)
    @sub_agent = SubAgents::ReviewTask.new(
      role: @role,
      arguments: { "task_id" => @task.id, "review_focus" => "check backslash escaping" },
      parent_role_run: @role_run
    )
  end

  test "tool_definition requires task_id and exposes review_focus" do
    defn = SubAgents::ReviewTask.tool_definition
    assert_equal "review_task", defn[:name]
    assert_includes defn[:inputSchema][:required], "task_id"
    assert defn[:inputSchema][:properties].key?(:review_focus)
  end

  test "tool_scope routes to the review-task tool set" do
    assert_equal :sub_agent_review_task, SubAgents::ReviewTask.tool_scope
  end

  test "system_prompt constrains the specialist to exactly one submit_review_decision call" do
    prompt = @sub_agent.system_prompt
    assert_includes prompt, "review specialist"
    assert_includes prompt, "Exactly one submit_review_decision call"
    assert_includes prompt, @role.title
  end

  test "user_message includes task id and optional review_focus" do
    message = @sub_agent.user_message
    assert_includes message, "Task id: #{@task.id}"
    assert_includes message, "backslash escaping"
  end
end
