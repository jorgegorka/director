require "test_helper"

class RoleSkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @unassigned_skill = skills(:acme_project_planning)
    @assigned_skill = skills(:acme_code_review)
    @widgets_skill = skills(:widgets_strategic_planning)
  end

  # --- Create ---

  test "should assign skill to role" do
    assert_difference("RoleSkill.count", 1) do
      post role_role_skills_url(@cto), params: { skill_id: @unassigned_skill.id }
    end
    assert_redirected_to role_url(@cto)
    assert_match @unassigned_skill.name, flash[:notice]
  end

  test "should not duplicate assignment (idempotent)" do
    assert_no_difference("RoleSkill.count") do
      post role_role_skills_url(@cto), params: { skill_id: @assigned_skill.id }
    end
    assert_redirected_to role_url(@cto)
  end

  test "should not assign skill from another company" do
    post role_role_skills_url(@cto), params: { skill_id: @widgets_skill.id }
    assert_response :not_found
  end

  test "should not assign skill to role from another company" do
    post role_role_skills_url(roles(:widgets_lead)), params: { skill_id: @unassigned_skill.id }
    assert_response :not_found
  end

  test "should redirect unauthenticated user on create" do
    sign_out
    post role_role_skills_url(@cto), params: { skill_id: @unassigned_skill.id }
    assert_redirected_to new_session_url
  end

  test "should redirect user without company on create" do
    user_without_company = User.create!(
      email_address: "nocompany_askl@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    post role_role_skills_url(@cto), params: { skill_id: @unassigned_skill.id }
    assert_redirected_to new_company_url
  end

  # --- Destroy ---

  test "should remove skill from role" do
    role_skill = role_skills(:cto_code_review)
    assert_difference("RoleSkill.count", -1) do
      delete role_role_skill_url(@cto, role_skill)
    end
    assert_redirected_to role_url(@cto)
    assert_match "removed from", flash[:notice]
  end

  test "should not remove role_skill belonging to another role" do
    role_skill = role_skills(:developer_data_analysis)
    delete role_role_skill_url(@cto, role_skill)
    assert_response :not_found
  end

  test "should not remove skill from role in another company" do
    role_skill = role_skills(:cto_code_review)
    delete role_role_skill_url(roles(:widgets_lead), role_skill)
    assert_response :not_found
  end

  test "should redirect unauthenticated user on destroy" do
    role_skill = role_skills(:cto_code_review)
    sign_out
    delete role_role_skill_url(@cto, role_skill)
    assert_redirected_to new_session_url
  end
end
