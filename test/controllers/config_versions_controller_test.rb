require "test_helper"

class ConfigVersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @role_version = config_versions(:role_edit_version)
    @role_budget_version = config_versions(:role_budget_version)
  end

  # --- Index ---

  test "should get index for role versions" do
    get config_versions_url(type: "Role", record_id: roles(:cto).id)
    assert_response :success
    assert_select "h1", "Version History"
  end

  test "should get index for role versions without assertions" do
    get config_versions_url(type: "Role", record_id: roles(:cto).id)
    assert_response :success
  end

  test "should redirect without type and record_id" do
    get config_versions_url
    assert_redirected_to root_url
  end

  test "should redirect for non-existent record" do
    get config_versions_url(type: "Role", record_id: 999999)
    assert_redirected_to root_url
  end

  # --- Show ---

  test "should show version detail" do
    get config_version_url(@role_version)
    assert_response :success
    assert_select ".version-detail"
  end

  test "should show snapshot table" do
    get config_version_url(@role_version)
    assert_response :success
    assert_select ".snapshot-table"
  end

  test "should show changeset diff" do
    get config_version_url(@role_version)
    assert_response :success
    assert_select ".version-diff"
  end

  test "should show rollback button" do
    get config_version_url(@role_version)
    assert_response :success
    assert_select "form[action=?]", rollback_config_version_path(@role_version)
  end

  # --- Rollback ---

  test "should rollback to version" do
    role = roles(:cto)
    role.update!(description: "Temporary change for rollback test")
    assert_equal "Temporary change for rollback test", role.description

    post rollback_config_version_url(@role_version)
    assert_redirected_to role_url(role)
    role.reload
    assert_equal "Chief Technology Officer", role.description
  end

  test "rollback records audit event" do
    assert_difference -> { AuditEvent.where(action: "config_rollback").count } do
      post rollback_config_version_url(@role_version)
    end
  end

  test "should not show versions from other project" do
    get config_version_url(@role_version)
    assert_response :success
    # Version belongs to acme, which is our current project
  end

  # --- Auth ---

  test "should redirect unauthenticated user" do
    sign_out
    get config_versions_url(type: "Role", record_id: roles(:cto).id)
    assert_redirected_to new_session_url
  end

  test "should redirect user without project" do
    user_without_project = User.create!(
      email_address: "versionless@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_project)
    get config_versions_url(type: "Role", record_id: roles(:cto).id)
    assert_redirected_to new_onboarding_project_url
  end
end
