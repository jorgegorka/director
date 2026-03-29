require "test_helper"

class GoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @mission = goals(:acme_mission)
    @objective = goals(:acme_objective_one)
    @sub_objective = goals(:acme_sub_objective)
    @widgets_mission = goals(:widgets_mission)
  end

  # --- Index ---

  test "should get index" do
    get goals_url
    assert_response :success
    assert_select ".goal-tree"
  end

  test "should only show goals for current company" do
    get goals_url
    assert_response :success
    assert_select ".goal-tree__title", text: "Build the best AI platform"
    assert_select ".goal-tree__title", text: "Dominate widget market", count: 0
  end

  test "index shows mission label on root goal" do
    get goals_url
    assert_select ".goal-tree__label--mission", minimum: 1
  end

  # --- Show ---

  test "should show goal" do
    get goal_url(@mission)
    assert_response :success
    assert_select "h1", "Build the best AI platform"
  end

  test "should show mission label for root goal" do
    get goal_url(@mission)
    assert_select ".goal-tree__label--mission", text: "Mission"
  end

  test "should show progress percentage" do
    get goal_url(@mission)
    assert_match(/\d+% complete/, response.body)
  end

  test "should show child objectives" do
    get goal_url(@mission)
    assert_select ".goal-tree__title", text: "Launch MVP by Q2"
    assert_select ".goal-tree__title", text: "Achieve 99.9% uptime"
  end

  test "should show linked tasks" do
    get goal_url(@objective)
    assert_select ".task-card__title a", text: "Design homepage"
    assert_select ".task-card__title a", text: "Fix login bug"
  end

  test "should not show goal from another company" do
    get goal_url(@widgets_mission)
    assert_response :not_found
  end

  test "should show breadcrumb for nested goal" do
    get goal_url(@sub_objective)
    assert_response :success
    assert_select ".goal-detail__breadcrumb", text: /Build the best AI platform/
    assert_select ".goal-detail__breadcrumb", text: /Launch MVP by Q2/
  end

  # --- New ---

  test "should get new" do
    get new_goal_url
    assert_response :success
    assert_select "form"
  end

  test "should get new with parent_id param" do
    get new_goal_url(parent_id: @mission.id)
    assert_response :success
    assert_select "form"
  end

  test "new goal form shows parent select" do
    get new_goal_url
    assert_select "select[name='goal[parent_id]']"
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
    assert_equal @company, goal.company
    assert_redirected_to goal_url(goal)
  end

  test "should create mission (no parent)" do
    assert_difference("Goal.count", 1) do
      post goals_url, params: {
        goal: {
          title: "New top-level mission",
          parent_id: ""
        }
      }
    end
    goal = Goal.order(:created_at).last
    assert goal.root?
  end

  test "should create objective under mission" do
    assert_difference("Goal.count", 1) do
      post goals_url, params: {
        goal: {
          title: "New objective",
          parent_id: @mission.id
        }
      }
    end
    goal = Goal.order(:created_at).last
    assert_equal @mission, goal.parent
  end

  test "should not create goal without title" do
    assert_no_difference("Goal.count") do
      post goals_url, params: {
        goal: { title: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create goal with cross-company parent" do
    assert_no_difference("Goal.count") do
      post goals_url, params: {
        goal: {
          title: "Cross-company objective",
          parent_id: @widgets_mission.id
        }
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
      goal: { title: "Updated mission title" }
    }
    assert_redirected_to goal_url(@mission)
    @mission.reload
    assert_equal "Updated mission title", @mission.title
  end

  test "should not update goal without title" do
    patch goal_url(@mission), params: {
      goal: { title: "" }
    }
    assert_response :unprocessable_entity
  end

  # --- Destroy ---

  test "should destroy goal" do
    # Use objective_two which has no children
    goal_to_delete = goals(:acme_objective_two)
    assert_difference("Goal.count", -1) do
      delete goal_url(goal_to_delete)
    end
    assert_redirected_to goals_url
  end

  test "destroying goal destroys children" do
    # objective_one has acme_sub_objective as a child
    assert_difference("Goal.count", -2) do
      delete goal_url(@objective)
    end
    assert_raises(ActiveRecord::RecordNotFound) { @sub_objective.reload }
  end

  test "destroying goal nullifies task goal_id" do
    # write_tests task is linked to acme_sub_objective; destroying acme_objective_one
    # cascades to acme_sub_objective which nullifies write_tests.goal_id
    task = tasks(:write_tests)
    assert_equal @sub_objective.id, task.goal_id

    delete goal_url(@objective)
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
    goal = goals(:acme_objective_two)  # has no role

    patch goal_path(goal), params: { goal: {
      title: goal.title,
      role_id: roles(:cto).id
    } }

    goal.reload
    assert_equal roles(:cto), goal.role
  end

  test "update clears goal role" do
    goal = goals(:acme_objective_one)  # has cto assigned

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

  test "requires company" do
    user_without_company = User.create!(
      email_address: "goalsless@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get goals_url
    assert_redirected_to new_company_url
  end
end
