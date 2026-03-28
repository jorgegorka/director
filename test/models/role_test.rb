require "test_helper"

class RoleTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
  end

  # --- Validations ---

  test "valid with title and company" do
    role = Role.new(title: "Designer", company: @company)
    assert role.valid?
  end

  test "invalid without title" do
    role = Role.new(title: nil, company: @company)
    assert_not role.valid?
    assert_includes role.errors[:title], "can't be blank"
  end

  test "invalid with duplicate title in same company" do
    role = Role.new(title: "CEO", company: @company)
    assert_not role.valid?
    assert_includes role.errors[:title], "already exists in this company"
  end

  test "allows same title in different companies" do
    role = Role.new(title: "CEO", company: companies(:widgets))
    assert role.valid?
  end

  test "invalid when parent belongs to different company" do
    role = Role.new(title: "Cross-company", company: companies(:widgets), parent: @ceo)
    assert_not role.valid?
    assert_includes role.errors[:parent], "must belong to the same company"
  end

  test "invalid when parent is self" do
    @ceo.parent = @ceo
    assert_not @ceo.valid?
    assert_includes @ceo.errors[:parent], "cannot be the role itself"
  end

  test "invalid when parent would create cycle" do
    # Developer -> CTO -> CEO. Setting CEO's parent to Developer creates a cycle.
    @ceo.parent = @developer
    assert_not @ceo.valid?
    assert_includes @ceo.errors[:parent], "cannot be a descendant of this role"
  end

  # --- Associations ---

  test "belongs to company via Tenantable" do
    assert_equal @company, @ceo.company
  end

  test "belongs to parent" do
    assert_equal @ceo, @cto.parent
  end

  test "has many children" do
    assert_includes @ceo.children, @cto
    assert_not_includes @ceo.children, @developer
  end

  test "root? returns true for parentless roles" do
    assert @ceo.root?
    assert_not @cto.root?
  end

  # --- Hierarchy methods ---

  test "ancestors returns chain to root" do
    ancestors = @developer.ancestors
    assert_equal [ @cto, @ceo ], ancestors
  end

  test "ancestors returns empty for root role" do
    assert_empty @ceo.ancestors
  end

  test "descendants returns all nested children" do
    descendants = @ceo.descendants
    assert_includes descendants, @cto
    assert_includes descendants, @developer
    assert_equal 2, descendants.size
  end

  test "depth returns hierarchy level" do
    assert_equal 0, @ceo.depth
    assert_equal 1, @cto.depth
    assert_equal 2, @developer.depth
  end

  # --- Scoping ---

  test "roots scope returns only parentless roles" do
    roots = Role.where(company: @company).roots
    assert_includes roots, @ceo
    assert_not_includes roots, @cto
    assert_not_includes roots, @developer
  end

  test "for_current_company scope filters by Current.company" do
    Current.company = @company
    roles = Role.for_current_company
    assert_includes roles, @ceo
    assert_includes roles, @cto
    assert_not_includes roles, roles(:widgets_lead)
  ensure
    Current.company = nil
  end

  # --- Deletion behavior ---

  test "destroying parent re-parents children to grandparent" do
    @cto.destroy
    @developer.reload
    assert_equal @ceo.id, @developer.parent_id
  end

  test "destroying root role makes children root" do
    @ceo.destroy
    @cto.reload
    assert_nil @cto.parent_id
  end

  test "destroying company destroys all roles" do
    role_count = @company.roles.count
    assert role_count > 0
    assert_difference("Role.count", -role_count) do
      @company.destroy
    end
  end

  # --- Auto-assignment ---

  test "first agent assignment creates agent_skills for role default skills" do
    # CEO role has no agent. Assigning process_agent should trigger auto-assignment.
    # CEO maps to: strategic_planning, company_vision, stakeholder_communication, decision_making, risk_assessment
    agent = agents(:process_agent)
    assert_equal 0, agent.agent_skills.count, "Agent should start with no skills"

    @ceo.update!(agent: agent)

    agent.reload
    skill_keys = agent.skills.pluck(:key).sort
    expected_keys = %w[company_vision decision_making risk_assessment stakeholder_communication strategic_planning]
    assert_equal expected_keys, skill_keys, "Agent should have all CEO default skills"
  end

  test "first agent assignment does not duplicate existing skills" do
    # claude_agent already has strategic_planning and code_review from fixtures.
    # Assigning claude_agent to CEO role should add the other 3 CEO skills
    # but NOT duplicate strategic_planning.
    agent = agents(:claude_agent)
    initial_count = agent.agent_skills.count
    assert initial_count > 0, "Agent should have some existing skills"

    # CEO has no agent. Assigning claude_agent triggers first assignment.
    @ceo.update!(agent: agent)

    agent.reload
    # strategic_planning should exist exactly once
    sp_count = agent.agent_skills.joins(:skill).where(skills: { key: "strategic_planning" }).count
    assert_equal 1, sp_count, "strategic_planning should not be duplicated"

    # Should have original skills + new CEO skills (minus the one already present)
    ceo_keys = %w[company_vision decision_making risk_assessment stakeholder_communication strategic_planning]
    new_keys = ceo_keys - %w[strategic_planning]
    assert_equal initial_count + new_keys.size, agent.agent_skills.count
  end

  test "reassignment does not trigger auto-assignment" do
    # CTO has claude_agent. Reassigning to http_agent should NOT give http_agent CTO skills.
    agent = agents(:http_agent)
    initial_skill_count = agent.agent_skills.count

    @cto.update!(agent: agent)

    agent.reload
    assert_equal initial_skill_count, agent.agent_skills.count,
      "Reassignment should not create new agent_skills"
  end

  test "unassigning agent does not trigger auto-assignment" do
    # CTO has claude_agent. Unassigning should not trigger anything.
    agent = agents(:claude_agent)
    initial_skill_count = agent.agent_skills.count

    @cto.update!(agent: nil)

    agent.reload
    assert_equal initial_skill_count, agent.agent_skills.count,
      "Unassigning agent should not change skills"
  end

  test "unknown role title silently skips auto-assignment" do
    # Create a role with a title not in default_skills.yml
    agent = agents(:process_agent)
    role = Role.create!(title: "Chief Happiness Officer", company: @company)

    assert_no_difference("AgentSkill.count") do
      role.update!(agent: agent)
    end
  end

  test "missing skill keys in company are silently skipped" do
    # Create a role with a known title but company has no matching skills.
    # widgets company only has strategic_planning in fixtures (not the full CEO set).
    widgets_company = companies(:widgets)
    widgets_agent = agents(:widgets_agent)
    role = Role.create!(title: "CEO", company: widgets_company)

    # This should create AgentSkill only for strategic_planning (the only CEO skill in widgets fixtures).
    # The other 4 CEO skills (company_vision, decision_making, risk_assessment, stakeholder_communication)
    # do not exist in widgets company, so they are silently skipped.
    assert_nothing_raised do
      role.update!(agent: widgets_agent)
    end

    widgets_agent.reload
    skill_keys = widgets_agent.skills.pluck(:key)
    assert_includes skill_keys, "strategic_planning",
      "Should assign skills that exist in the company"
    assert_equal 1, widgets_agent.agent_skills.count,
      "Should only assign skills that exist in the company (not all 5 CEO defaults)"
  end

  test "default_skill_keys_for returns empty array for unknown title" do
    assert_equal [], Role.default_skill_keys_for("Nonexistent Role")
  end

  test "default_skill_keys_for is case-insensitive" do
    ceo_keys = Role.default_skill_keys_for("CEO")
    assert_equal 5, ceo_keys.size
    assert_includes ceo_keys, "strategic_planning"

    ceo_keys_lower = Role.default_skill_keys_for("ceo")
    assert_equal ceo_keys.sort, ceo_keys_lower.sort
  end
end
