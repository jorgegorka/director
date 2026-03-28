require "test_helper"

class AgentSkillTest < ActiveSupport::TestCase
  setup do
    @claude_agent = agents(:claude_agent)
    @http_agent = agents(:http_agent)
    @widgets_agent = agents(:widgets_agent)
    @acme_skill = skills(:acme_code_review)
    @widgets_skill = skills(:widgets_strategic_planning)
  end

  # --- Validations ---

  test "valid with agent and skill from same company" do
    agent_skill = AgentSkill.new(agent: @claude_agent, skill: skills(:acme_data_analysis))
    assert agent_skill.valid?
  end

  test "invalid with duplicate skill on same agent" do
    agent_skill = AgentSkill.new(agent: @claude_agent, skill: @acme_skill)
    assert_not agent_skill.valid?
    assert agent_skill.errors[:skill_id].any?
  end

  test "allows same skill on different agents" do
    agent_skill = AgentSkill.new(agent: @http_agent, skill: @acme_skill)
    assert agent_skill.valid?
  end

  test "invalid when agent and skill from different companies" do
    agent_skill = AgentSkill.new(agent: @claude_agent, skill: @widgets_skill)
    assert_not agent_skill.valid?
    assert_includes agent_skill.errors[:skill], "must belong to the same company as the agent"
  end

  test "invalid when widget agent assigned acme skill" do
    agent_skill = AgentSkill.new(agent: @widgets_agent, skill: @acme_skill)
    assert_not agent_skill.valid?
  end

  # --- Associations ---

  test "belongs to agent" do
    assert_equal @claude_agent, agent_skills(:claude_code_review).agent
  end

  test "belongs to skill" do
    assert_equal @acme_skill, agent_skills(:claude_code_review).skill
  end
end
