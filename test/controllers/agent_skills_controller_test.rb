require "test_helper"

class AgentSkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @unassigned_skill = skills(:acme_project_planning) # not assigned to claude_agent
    @assigned_skill = skills(:acme_code_review) # already assigned to claude_agent via claude_code_review fixture
    @widgets_skill = skills(:widgets_strategic_planning)
  end

  # --- Create ---

  test "should assign skill to agent" do
    assert_difference("AgentSkill.count", 1) do
      post agent_agent_skills_url(@claude_agent), params: { skill_id: @unassigned_skill.id }
    end
    assert_redirected_to agent_url(@claude_agent)
    assert_match @unassigned_skill.name, flash[:notice]
  end

  test "should not duplicate assignment (idempotent)" do
    # @assigned_skill (acme_code_review) is already assigned via claude_code_review fixture
    assert_no_difference("AgentSkill.count") do
      post agent_agent_skills_url(@claude_agent), params: { skill_id: @assigned_skill.id }
    end
    assert_redirected_to agent_url(@claude_agent)
  end

  test "should not assign skill from another company" do
    # @widgets_skill belongs to widgets company; Current.company.skills.find should raise RecordNotFound
    post agent_agent_skills_url(@claude_agent), params: { skill_id: @widgets_skill.id }
    assert_response :not_found
  end

  test "should not assign skill to agent from another company" do
    # widgets_agent belongs to widgets company; set_agent scoped to Current.company.agents should raise RecordNotFound
    post agent_agent_skills_url(agents(:widgets_agent)), params: { skill_id: @unassigned_skill.id }
    assert_response :not_found
  end

  test "should redirect unauthenticated user on create" do
    sign_out
    post agent_agent_skills_url(@claude_agent), params: { skill_id: @unassigned_skill.id }
    assert_redirected_to new_session_url
  end

  test "should redirect user without company on create" do
    user_without_company = User.create!(
      email_address: "nocompany_askl@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    post agent_agent_skills_url(@claude_agent), params: { skill_id: @unassigned_skill.id }
    assert_redirected_to new_company_url
  end

  # --- Destroy ---

  test "should remove skill from agent" do
    agent_skill = agent_skills(:claude_code_review)
    assert_difference("AgentSkill.count", -1) do
      delete agent_agent_skill_url(@claude_agent, agent_skill)
    end
    assert_redirected_to agent_url(@claude_agent)
    assert_match "removed from", flash[:notice]
  end

  test "should not remove agent_skill belonging to another agent" do
    # http_data_analysis belongs to http_agent; trying to destroy it via claude_agent's nested route should 404
    agent_skill = agent_skills(:http_data_analysis)
    delete agent_agent_skill_url(@claude_agent, agent_skill)
    assert_response :not_found
  end

  test "should not remove skill from agent in another company" do
    # widgets_agent is in widgets company; set_agent scoped to Current.company.agents raises RecordNotFound
    agent_skill = agent_skills(:claude_code_review)
    delete agent_agent_skill_url(agents(:widgets_agent), agent_skill)
    assert_response :not_found
  end

  test "should redirect unauthenticated user on destroy" do
    agent_skill = agent_skills(:claude_code_review)
    sign_out
    delete agent_agent_skill_url(@claude_agent, agent_skill)
    assert_redirected_to new_session_url
  end
end
