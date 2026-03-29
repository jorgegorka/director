require "test_helper"

class RoleTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
  end

  # --- Index ---

  test "should get index" do
    get role_templates_url
    assert_response :success
  end

  test "should display all 5 department templates" do
    get role_templates_url
    assert_select ".template-card", 5
  end

  test "should display template names" do
    get role_templates_url
    assert_select ".template-card__name", text: "Engineering"
    assert_select ".template-card__name", text: "Marketing"
  end

  test "should display role counts on cards" do
    get role_templates_url
    assert_select ".template-card__role-count"
  end

  # --- Show ---

  test "should show template detail" do
    get role_template_url("engineering")
    assert_response :success
  end

  test "should display template name as heading" do
    get role_template_url("engineering")
    assert_select "h1", "Engineering"
  end

  test "should display hierarchy tree" do
    get role_template_url("engineering")
    assert_select ".hierarchy-tree"
    assert_select ".hierarchy-tree__node"
  end

  test "should display role titles in hierarchy" do
    get role_template_url("engineering")
    assert_select ".hierarchy-tree__title", text: "CTO"
    assert_select ".hierarchy-tree__title", text: "Engineer"
  end

  test "should display skill badges in hierarchy" do
    get role_template_url("engineering")
    assert_select ".skill-badge", minimum: 1
  end

  test "should display apply button" do
    get role_template_url("engineering")
    assert_select "button[type=submit]", text: "Apply Template"
  end

  test "should return 404 for unknown template" do
    get role_template_url("nonexistent")
    assert_response :not_found
  end

  # --- Apply ---

  test "should apply template and redirect with notice" do
    post apply_role_template_url("engineering")
    assert_redirected_to roles_url
    follow_redirect!
    assert_select ".flash--notice"
  end

  test "should create roles from template" do
    # engineering template has 5 roles; acme fixture already has "CTO", so 4 are created
    assert_difference("@company.roles.count", 4) do
      post apply_role_template_url("engineering")
    end
  end

  test "should show summary in flash after apply" do
    post apply_role_template_url("engineering")
    assert_redirected_to roles_url
    assert flash[:notice].present?
    assert_match(/Created/, flash[:notice])
  end

  test "should handle already-existing roles gracefully" do
    # Apply once to create remaining roles
    post apply_role_template_url("engineering")

    # Apply again — all 5 roles now exist, should skip all
    assert_no_difference("@company.roles.count") do
      post apply_role_template_url("engineering")
    end
    assert_redirected_to roles_url
    assert flash[:notice].present?
    assert_match(/skipped/i, flash[:notice])
  end

  test "should return 404 when applying unknown template" do
    post apply_role_template_url("nonexistent")
    assert_response :not_found
  end

  # --- Auth guard ---

  test "should require company for index" do
    # Create a fresh user with no company membership
    user_without_company = User.create!(
      email_address: "no_company@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get role_templates_url
    assert_redirected_to new_company_path
  end
end
