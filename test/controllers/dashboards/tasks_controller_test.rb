require "test_helper"

class Dashboards::TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    post project_switch_url(projects(:acme))
  end

  test "should get index" do
    get dashboard_tasks_url
    assert_response :success
  end

  test "renders kanban columns" do
    get dashboard_tasks_url
    assert_response :success
    assert_select ".kanban__column", 6
  end

  test "kanban shows tasks in correct columns" do
    get dashboard_tasks_url
    assert_response :success
    assert_select ".kanban__column[data-status='in_progress'] .kanban-card", minimum: 1
  end

  test "kanban cards show task title" do
    get dashboard_tasks_url
    assert_response :success
    assert_select ".kanban-card__title", text: /Design homepage/
  end

  test "kanban does not show other project tasks" do
    get dashboard_tasks_url
    assert_response :success
    assert_select ".kanban-card__title", text: /Update widget catalog/, count: 0
  end

  test "kanban cards are draggable" do
    get dashboard_tasks_url
    assert_response :success
    assert_select ".kanban-card[draggable='true']", minimum: 1
  end

  test "kanban shows new task link" do
    get dashboard_tasks_url
    assert_response :success
    assert_select "a[href='#{new_task_path}']", text: "New Task"
  end

  test "kanban cards have turbo stream target ids" do
    get dashboard_tasks_url
    assert_response :success
    assert_select "[id^='kanban-task-']", minimum: 1
  end

  test "kanban column bodies have target ids" do
    get dashboard_tasks_url
    assert_response :success
    assert_select "[id^='kanban-column-body-']", 6
  end

  test "renders full page with tasks tab active" do
    get dashboard_tasks_url
    assert_response :success
    assert_select ".dashboard-tab--active", text: "Tasks"
  end

  test "requires authentication" do
    sign_out
    get dashboard_tasks_url
    assert_redirected_to new_session_url
  end

  test "requires project" do
    user_without_project = User.create!(
      email_address: "noproject@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get dashboard_tasks_url
    assert_redirected_to new_onboarding_project_url
  end
end
