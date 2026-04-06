require "test_helper"

class RoleRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @role = roles(:cto)
  end

  # --- Index ---

  test "index lists role runs" do
    get role_role_runs_url(@role)
    assert_response :success
    assert_select "table"
  end

  test "index requires authentication" do
    sign_out
    get role_role_runs_url(@role)
    assert_redirected_to new_session_url
  end

  test "index scopes to current project" do
    other_role = roles(:widgets_lead)
    get role_role_runs_url(other_role)
    assert_redirected_to root_url
  end

  test "index shows empty state when no runs" do
    @role.role_runs.delete_all
    get role_role_runs_url(@role)
    assert_response :success
    assert_select ".role-runs__empty"
  end

  # --- Show ---

  test "show displays role run details" do
    run = role_runs(:completed_run)
    get role_role_run_url(@role, run)
    assert_response :success
    assert_select ".role-run-detail"
  end

  test "show includes output stream container" do
    run = role_runs(:completed_run)
    get role_role_run_url(@role, run)
    assert_response :success
    assert_select ".role-run-output__stream"
  end

  test "show rejects run from different role" do
    other_run = role_runs(:running_run) # belongs to developer
    get role_role_run_url(@role, other_run)
    assert_redirected_to root_url
  end

  test "show displays error message for failed run" do
    run = @role.role_runs.create!(
      project: @project,
      status: :failed,
      trigger_type: "task_assigned",
      error_message: "Something went wrong",
      completed_at: Time.current
    )
    get role_role_run_url(@role, run)
    assert_response :success
    assert_select ".role-run-detail__error-banner"
  end

  # --- Cancel ---

  test "cancel marks running run as cancelled" do
    run = @role.role_runs.create!(
      project: @project,
      status: :running,
      trigger_type: "task_assigned",
      started_at: Time.current
    )
    @role.update!(status: :running)

    killed = []
    ClaudeLocalAdapter.define_singleton_method(:kill_session) { |name| killed << name }

    post cancel_role_role_run_url(@role, run)
    assert_redirected_to role_role_run_path(@role, run)

    run.reload
    assert run.cancelled?
    assert_not_nil run.completed_at

    @role.reload
    assert @role.idle?

    assert_includes killed, "director_run_#{run.id}"
  ensure
    if ClaudeLocalAdapter.singleton_class.method_defined?(:kill_session, false)
      ClaudeLocalAdapter.singleton_class.remove_method(:kill_session)
    end
  end

  test "cancel completed run returns alert" do
    run = role_runs(:completed_run)
    post cancel_role_role_run_url(@role, run)
    assert_redirected_to role_role_run_path(@role, run)
    assert_equal "Run is already completed.", flash[:alert]
  end

  test "cancel requires authentication" do
    sign_out
    run = role_runs(:completed_run)
    post cancel_role_role_run_url(@role, run)
    assert_redirected_to new_session_url
  end

  test "cancel scopes to current project" do
    other_role = roles(:widgets_lead)
    run = other_role.role_runs.create!(
      project: projects(:widgets),
      status: :running,
      trigger_type: "task_assigned",
      started_at: Time.current
    )
    post cancel_role_role_run_url(other_role, run)
    assert_redirected_to root_url
  end
end
