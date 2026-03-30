require "test_helper"

class RoleHiringsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)

    @cto = roles(:cto)
  end

  # ==========================================================================
  # Agent API tests (Bearer token auth)
  # ==========================================================================

  test "agent can hire subordinate role via API with auto_hire enabled" do
    sign_out
    @cto.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      post hire_role_url(@cto, format: :json),
           params: { template_role_title: "VP Engineering", budget_cents: 20000 },
           headers: { "Authorization" => "Bearer #{@cto.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]
    assert json["role_id"].present?
    assert_match "VP Engineering", json["message"]
  end

  test "agent hire creates pending request when auto_hire disabled" do
    sign_out

    assert_difference "PendingHire.count", 1 do
      post hire_role_url(@cto, format: :json),
           params: { template_role_title: "VP Engineering", budget_cents: 20000 },
           headers: { "Authorization" => "Bearer #{@cto.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "pending_approval", json["status"]
    assert_match "approval", json["message"]
  end

  test "agent cannot hire invalid role title via API" do
    sign_out
    @cto.update!(auto_hire_enabled: true)

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "CEO", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
  end

  test "agent cannot hire with excessive budget via API" do
    sign_out
    @cto.update!(auto_hire_enabled: true)

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "VP Engineering", budget_cents: 999_999 },
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_match(/budget/i, json["error"])
  end

  test "API returns 401 for invalid Bearer token" do
    sign_out

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "VP Engineering", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer invalid_token" }

    assert_response :unauthorized
  end

  test "agent cannot hire for role in another company" do
    sign_out
    widgets_lead = roles(:widgets_lead)

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "VP Engineering", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer #{widgets_lead.api_token}" }

    assert_response :not_found
  end

  # ==========================================================================
  # Human-initiated hire tests (session auth)
  # ==========================================================================

  test "human user can trigger hire for a role" do
    @cto.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      post hire_role_url(@cto),
           params: { template_role_title: "VP Engineering", budget_cents: 20000 }
    end

    assert_redirected_to role_path(@cto)
    assert_match "VP Engineering", flash[:notice]
  end

  test "human user sees error for invalid hire" do
    @cto.update!(auto_hire_enabled: true)

    post hire_role_url(@cto),
         params: { template_role_title: "Nonexistent", budget_cents: 20000 }

    assert_redirected_to role_path(@cto)
    assert flash[:alert].present?
  end
end
