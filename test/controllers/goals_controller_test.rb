require "test_helper"

class GoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @root_task = tasks(:design_homepage)
  end

  # --- Index ---

  test "should get index listing root tasks" do
    get goals_url
    assert_response :success
  end

  # --- Show ---

  test "should show goal (root task)" do
    get goal_url(@root_task)
    assert_response :success
  end

  test "should not show non-root task as goal" do
    get goal_url(tasks(:subtask_one))
    assert_redirected_to root_path
  end

  # --- New ---

  test "should get new goal form" do
    get new_goal_url
    assert_response :success
    assert_select "form"
  end

  test "new form scopes fields under root_task (regression: form_with as: ignored with model:)" do
    get new_goal_url
    assert_response :success
    assert_select "input[name='root_task[title]']"
    assert_select "input[name='root_task[description]'], textarea[name='root_task[description]']"
  end

  # --- Create ---

  test "should create goal with valid params" do
    assert_difference("Task.roots.count", 1) do
      post goals_url, params: {
        root_task: {
          title: "New top-level goal",
          description: "A mission for the team",
          priority: "high",
          assignee_id: @cto.id
        }
      }
    end
    goal = Task.roots.order(:created_at).last
    assert_equal "New top-level goal", goal.title
    assert_equal "high", goal.priority
    assert_nil goal.parent_task_id
    assert_equal @cto, goal.assignee
    assert_equal @ceo, goal.creator, "defaults creator to top-level active role"
    assert_redirected_to goal_url(goal)
  end

  test "should create goal without assignee" do
    assert_difference("Task.roots.count", 1) do
      post goals_url, params: {
        root_task: { title: "Unassigned mission" }
      }
    end
    goal = Task.roots.order(:created_at).last
    assert_nil goal.assignee
    assert_equal @ceo, goal.creator
  end

  # Regression: the only top-level role in a project may be terminated
  # (the state that triggered the "+ Goal" button failure on the org chart).
  # Creator should default to the assignee's root ancestor regardless of status.
  test "creates goal assigned to subordinate when top-level role is terminated" do
    @ceo.update!(status: :terminated)
    assert_difference("Task.roots.count", 1) do
      post goals_url, params: {
        root_task: { title: "Still works", assignee_id: @cto.id }
      }
    end
    goal = Task.roots.order(:created_at).last
    assert_equal @cto, goal.assignee
    assert_equal @ceo, goal.creator
  end

  test "creates unassigned goal when top-level role is terminated" do
    @ceo.update!(status: :terminated)
    assert_difference("Task.roots.count", 1) do
      post goals_url, params: { root_task: { title: "No owner" } }
    end
    goal = Task.roots.order(:created_at).last
    assert_nil goal.assignee
    assert_equal @ceo, goal.creator
  end

  test "creates goal assigned to a terminated top-level role itself" do
    @ceo.update!(status: :terminated)
    assert_difference("Task.roots.count", 1) do
      post goals_url, params: {
        root_task: { title: "Legacy cleanup", assignee_id: @ceo.id }
      }
    end
    goal = Task.roots.order(:created_at).last
    assert_equal @ceo, goal.assignee
    assert_equal @ceo, goal.creator
  end

  test "should not create goal with blank title" do
    assert_no_difference("Task.count") do
      post goals_url, params: { root_task: { title: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should reject unscoped params (regression: form must scope under root_task)" do
    assert_no_difference("Task.count") do
      post goals_url, params: {
        task: { title: "Wrong scope", description: "nope" }
      }
    end
    assert_response :bad_request
  end

  # --- Edit / Update ---

  test "should get edit form" do
    get edit_goal_url(@root_task)
    assert_response :success
    assert_select "form"
    assert_select "input[name='root_task[title]']"
  end

  test "should update goal" do
    patch goal_url(@root_task), params: {
      root_task: { title: "Renamed mission", description: "Updated" }
    }
    assert_redirected_to goal_url(@root_task)
    @root_task.reload
    assert_equal "Renamed mission", @root_task.title
    assert_equal "Updated", @root_task.description
  end

  test "should not update goal with blank title" do
    patch goal_url(@root_task), params: { root_task: { title: "" } }
    assert_response :unprocessable_entity
  end

  # --- Destroy ---

  test "should destroy goal" do
    assert_difference("Task.roots.count", -1) do
      delete goal_url(@root_task)
    end
    assert_redirected_to goals_url
  end

  # --- Org-chart modal form (regression for the reported bug) ---

  test "org chart renders goal modal form with root_task scope" do
    get roles_url
    assert_response :success
    assert_select "input[name='root_task[title]']"
    assert_select "input[name='root_task[assignee_id]'][type='hidden']"
  end

  # --- Auth ---

  test "should redirect unauthenticated user" do
    sign_out
    get goals_url
    assert_redirected_to new_session_url
  end
end
