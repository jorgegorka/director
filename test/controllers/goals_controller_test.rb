require "test_helper"

class GoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @mission = goals(:acme_mission)
    @objective = goals(:acme_objective_one)
    @sub_objective = goals(:acme_sub_objective)
    @widgets_mission = goals(:widgets_mission)
  end

  # --- Index ---

  test "should get index" do
    get goals_url
    assert_response :success
    assert_select ".goal-list"
  end

  test "should only show goals for current project" do
    get goals_url
    assert_response :success
    assert_select ".goal-list__title", text: "Build the best AI platform"
    assert_select ".goal-list__title", text: "Dominate widget market", count: 0
  end

  # --- Show ---

  test "should show goal" do
    get goal_url(@mission)
    assert_response :success
    assert_select "h1", "Build the best AI platform"
  end

  test "should show progress percentage" do
    get goal_url(@mission)
    assert_match(/\d+% complete/, response.body)
  end

  test "should show linked tasks" do
    get goal_url(@objective)
    assert_select ".task-card__title a", text: "Design homepage"
    assert_select ".task-card__title a", text: "Fix login bug"
  end

  test "should not show goal from another project" do
    get goal_url(@widgets_mission)
    assert_redirected_to root_url
  end

  # --- New ---

  test "should get new" do
    get new_goal_url
    assert_response :success
    assert_select "form"
  end

  test "new goal form has no parent select" do
    get new_goal_url
    assert_select "select[name='goal[parent_id]']", count: 0
  end

  # --- Create ---

  test "should create goal" do
    assert_difference("Goal.count", 1) do
      post goals_url, params: {
        goal: {
          title: "New test goal",
          description: "A goal for testing"
        }
      }
    end
    goal = Goal.order(:created_at).last
    assert_equal "New test goal", goal.title
    assert_equal @project, goal.project
    assert_redirected_to goal_url(goal)
  end

  test "should not create goal without title" do
    assert_no_difference("Goal.count") do
      post goals_url, params: {
        goal: { title: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- Edit ---

  test "should get edit" do
    get edit_goal_url(@mission)
    assert_response :success
    assert_select "form"
  end

  # --- Update ---

  test "should update goal" do
    patch goal_url(@mission), params: {
      goal: { title: "Updated goal title" }
    }
    assert_redirected_to goal_url(@mission)
    @mission.reload
    assert_equal "Updated goal title", @mission.title
  end

  test "should not update goal without title" do
    patch goal_url(@mission), params: {
      goal: { title: "" }
    }
    assert_response :unprocessable_entity
  end

  # --- Destroy ---

  test "should destroy goal" do
    goal_to_delete = goals(:acme_objective_two)
    assert_difference("Goal.count", -1) do
      delete goal_url(goal_to_delete)
    end
    assert_redirected_to goals_url
  end

  test "destroying goal nullifies its tasks goal_id" do
    task = tasks(:write_tests)
    assert_equal @sub_objective.id, task.goal_id

    delete goal_url(@sub_objective)
    task.reload
    assert_nil task.goal_id
  end

  # --- Role assignment ---

  test "create assigns role to goal" do
    role = roles(:cto)

    assert_difference "Goal.count", 1 do
      post goals_path, params: { goal: {
        title: "Role-assigned goal",
        role_id: role.id
      } }
    end

    goal = Goal.last
    assert_equal role, goal.role
  end

  test "update changes goal role" do
    goal = goals(:acme_objective_two)

    patch goal_path(goal), params: { goal: {
      title: goal.title,
      role_id: roles(:cto).id
    } }

    goal.reload
    assert_equal roles(:cto), goal.role
  end

  test "update clears goal role" do
    goal = goals(:acme_objective_one)

    patch goal_path(goal), params: { goal: {
      title: goal.title,
      role_id: ""
    } }

    goal.reload
    assert_nil goal.role
  end

  # --- Auth ---

  test "requires authentication" do
    sign_out
    get goals_url
    assert_redirected_to new_session_url
  end

  test "requires project" do
    user_without_project = User.create!(
      email_address: "goalsless@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get goals_url
    assert_redirected_to new_project_url
  end
end
