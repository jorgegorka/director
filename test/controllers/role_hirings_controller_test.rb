require "test_helper"

class RoleHiringsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)

    @cmo = roles(:cmo)
  end

  # ==========================================================================
  # Agent API tests (Bearer token auth)
  # ==========================================================================

  test "agent can hire subordinate role via API with auto_hire enabled" do
    sign_out
    @cmo.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      post hire_role_url(@cmo, format: :json),
           params: { template_role_title: "Marketing Planner", budget_cents: 20000 },
           headers: { "Authorization" => "Bearer #{@cmo.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]
    assert json["role_id"].present?
    assert_match "Marketing Planner", json["message"]
  end

  test "agent hire creates pending request when auto_hire disabled" do
    sign_out

    assert_difference "PendingHire.count", 1 do
      post hire_role_url(@cmo, format: :json),
           params: { template_role_title: "Marketing Planner", budget_cents: 20000 },
           headers: { "Authorization" => "Bearer #{@cmo.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "pending_approval", json["status"]
    assert_match "approval", json["message"]
  end

  test "agent cannot hire invalid role title via API" do
    sign_out
    @cmo.update!(auto_hire_enabled: true)

    post hire_role_url(@cmo, format: :json),
         params: { template_role_title: "CEO", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer #{@cmo.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
  end

  test "agent cannot hire with excessive budget via API" do
    sign_out
    @cmo.update!(auto_hire_enabled: true)

    post hire_role_url(@cmo, format: :json),
         params: { template_role_title: "Marketing Planner", budget_cents: 999_999 },
         headers: { "Authorization" => "Bearer #{@cmo.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_match(/budget/i, json["error"])
  end

  test "API returns 401 for invalid Bearer token" do
    sign_out

    post hire_role_url(@cmo, format: :json),
         params: { template_role_title: "Marketing Planner", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer invalid_token" }

    assert_response :unauthorized
  end

  test "agent cannot hire for role in another company" do
    sign_out
    widgets_lead = roles(:widgets_lead)

    post hire_role_url(@cmo, format: :json),
         params: { template_role_title: "Marketing Planner", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer #{widgets_lead.api_token}" }

    assert_response :not_found
  end

  # ==========================================================================
  # Human-initiated hire tests (session auth)
  # ==========================================================================

  test "human user can trigger hire for a role" do
    @cmo.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      post hire_role_url(@cmo),
           params: { template_role_title: "Marketing Planner", budget_cents: 20000 }
    end

    assert_redirected_to role_path(@cmo)
    assert_match "Marketing Planner", flash[:notice]
  end

  test "human user sees error for invalid hire" do
    @cmo.update!(auto_hire_enabled: true)

    post hire_role_url(@cmo),
         params: { template_role_title: "Nonexistent", budget_cents: 20000 }

    assert_redirected_to role_path(@cmo)
    assert flash[:alert].present?
  end

  # ==========================================================================
  # Approval flow tests
  # ==========================================================================

  test "approving a role with pending hire creates the hired role" do
    pending_hire = PendingHire.create!(
      role: @cmo,
      company: @company,
      template_role_title: "Marketing Planner",
      budget_cents: 20000
    )
    @cmo.update!(status: :pending_approval, pause_reason: "Awaiting approval to hire Marketing Planner")

    assert_difference "Role.count", 1 do
      post approve_role_url(@cmo)
    end

    assert_redirected_to role_path(@cmo)

    @cmo.reload
    assert @cmo.idle?

    pending_hire.reload
    assert pending_hire.approved?

    new_role = @company.roles.find_by(title: "Marketing Planner")
    assert_not_nil new_role
    assert_equal @cmo, new_role.parent
  end

  test "rejecting a role with pending hire does not create role" do
    pending_hire = PendingHire.create!(
      role: @cmo,
      company: @company,
      template_role_title: "Marketing Planner",
      budget_cents: 20000
    )
    @cmo.update!(status: :pending_approval, pause_reason: "Awaiting approval to hire Marketing Planner")

    assert_no_difference "Role.count" do
      post reject_role_url(@cmo), params: { reason: "Not needed now" }
    end

    assert_redirected_to role_path(@cmo)

    @cmo.reload
    assert @cmo.paused?

    pending_hire.reload
    assert pending_hire.rejected?
  end
end
