require "test_helper"

class RolesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
  end

  # --- Index ---

  test "should get index" do
    get roles_url
    assert_response :success
    assert_select ".role-card", minimum: 3
  end

  test "should only show roles for current company" do
    get roles_url
    assert_response :success
    assert_select ".role-card__title", text: "CEO"
    assert_select ".role-card__title", text: "Operations Lead", count: 0
  end

  # --- Show ---

  test "should show role" do
    get role_url(@ceo)
    assert_response :success
    assert_select "h1", "CEO"
  end

  test "should show direct reports on role detail" do
    get role_url(@ceo)
    assert_response :success
    assert_select ".role-card__title", text: "CTO"
  end

  test "should not show role from another company" do
    get role_url(roles(:widgets_lead))
    assert_response :not_found
  end

  # --- New / Create ---

  test "should get new role form" do
    get new_role_url
    assert_response :success
    assert_select "form"
    assert_select "select[name='role[parent_id]']"
  end

  test "should create role" do
    assert_difference("Role.count", 1) do
      post roles_url, params: {
        role: { title: "Designer", description: "UI/UX design", job_spec: "Design interfaces", parent_id: @cto.id }
      }
    end
    role = Role.order(:created_at).last
    assert_equal "Designer", role.title
    assert_equal @cto, role.parent
    assert_equal @company, role.company
    assert_redirected_to role_url(role)
  end

  test "should create root role with no parent" do
    assert_difference("Role.count", 1) do
      post roles_url, params: {
        role: { title: "Advisor", description: "External advisor" }
      }
    end
    role = Role.order(:created_at).last
    assert_nil role.parent_id
  end

  test "should not create role with blank title" do
    assert_no_difference("Role.count") do
      post roles_url, params: { role: { title: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create role with duplicate title" do
    assert_no_difference("Role.count") do
      post roles_url, params: { role: { title: "CEO" } }
    end
    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test "should get edit form" do
    get edit_role_url(@cto)
    assert_response :success
    assert_select "form"
  end

  test "should update role" do
    patch role_url(@cto), params: { role: { title: "VP Engineering", description: "Updated description" } }
    assert_redirected_to role_url(@cto)
    @cto.reload
    assert_equal "VP Engineering", @cto.title
    assert_equal "Updated description", @cto.description
  end

  test "should update role parent" do
    # Move developer to report directly to CEO instead of CTO
    patch role_url(@developer), params: { role: { parent_id: @ceo.id } }
    assert_redirected_to role_url(@developer)
    @developer.reload
    assert_equal @ceo, @developer.parent
  end

  test "should not update role with blank title" do
    patch role_url(@cto), params: { role: { title: "" } }
    assert_response :unprocessable_entity
  end

  # --- Destroy ---

  test "should destroy role and re-parent children" do
    # CTO has developer as child. Deleting CTO should re-parent developer to CEO.
    assert_difference("Role.count", -1) do
      delete role_url(@cto)
    end
    assert_redirected_to roles_url
    @developer.reload
    assert_equal @ceo.id, @developer.parent_id
  end

  test "should destroy root role and make children root" do
    # Delete CEO -- CTO should become root
    assert_difference("Role.count", -1) do
      delete role_url(@ceo)
    end
    @cto.reload
    assert_nil @cto.parent_id
  end

  # --- Auth / Scoping ---

  test "should redirect unauthenticated user" do
    sign_out
    get roles_url
    assert_redirected_to new_session_url
  end

  test "should redirect user without company" do
    user_without_company = User.create!(email_address: "lonely@example.com", password: "password", password_confirmation: "password")
    sign_in_as(user_without_company)
    get roles_url
    assert_redirected_to new_company_url
  end
end
