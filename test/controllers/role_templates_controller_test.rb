require "test_helper"

class RoleTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
  end

  # --- Index ---

  test "should get index" do
    get role_templates_url
    assert_response :success
  end

  test "should display template cards" do
    get role_templates_url
    assert_select ".template-card", RoleTemplates::Registry.all.size
  end

  test "should display template names" do
    get role_templates_url
    assert_select ".template-card__name", text: "Marketing"
  end

  test "should display role counts on cards" do
    get role_templates_url
    assert_select ".template-card__role-count"
  end

  # --- Show ---

  test "should show template detail" do
    get role_template_url("marketing")
    assert_response :success
  end

  test "should display template name as heading" do
    get role_template_url("marketing")
    assert_select "h1", "Marketing"
  end

  test "should display hierarchy tree" do
    get role_template_url("marketing")
    assert_select ".hierarchy-tree"
    assert_select ".hierarchy-tree__node"
  end

  test "should display role titles in hierarchy" do
    get role_template_url("marketing")
    assert_select ".hierarchy-tree__title", text: "CMO"
    assert_select ".hierarchy-tree__title", text: "Marketing Planner"
  end

  test "should display skill badges in hierarchy" do
    get role_template_url("marketing")
    assert_select ".skill-badge", minimum: 1
  end

  test "should display apply button" do
    get role_template_url("marketing")
    assert_select "button[type=submit]", text: "Apply Template"
  end

  test "should return 404 for unknown template" do
    get role_template_url("nonexistent")
    assert_redirected_to root_url
  end

  # --- Apply ---

  test "should apply template and redirect with notice" do
    post apply_role_template_url("marketing")
    assert_redirected_to roles_url
    follow_redirect!
    assert_select ".flash--notice"
  end

  test "should create roles from template" do
    # acme already has CMO fixture, so 8 of 9 marketing roles are created
    assert_difference("@project.roles.count", 8) do
      post apply_role_template_url("marketing")
    end
  end

  test "should show summary in flash after apply" do
    post apply_role_template_url("marketing")
    assert_redirected_to roles_url
    assert flash[:notice].present?
    assert_match(/Created/, flash[:notice])
  end

  test "should handle already-existing roles gracefully" do
    post apply_role_template_url("marketing")

    assert_no_difference("@project.roles.count") do
      post apply_role_template_url("marketing")
    end
    assert_redirected_to roles_url
    assert flash[:notice].present?
    assert_match(/skipped/i, flash[:notice])
  end

  test "should return 404 when applying unknown template" do
    post apply_role_template_url("nonexistent")
    assert_redirected_to root_url
  end

  # --- Auth guard ---

  test "should require project for index" do
    user_without_project = User.create!(
      email_address: "no_project@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get role_templates_url
    assert_redirected_to new_project_path
  end
end
