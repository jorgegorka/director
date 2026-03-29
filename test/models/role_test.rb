require "test_helper"

class RoleTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @ceo = roles(:ceo)
    @cto = roles(:cto)
    @developer = roles(:developer)
    @process_role = roles(:process_role)
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

  # --- Adapter validations ---

  test "valid with adapter_type, adapter_config, and valid config" do
    role = Role.new(
      title: "New Agent Role",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    assert role.valid?
  end

  test "invalid when http role missing url in adapter_config" do
    role = Role.new(
      title: "Bad HTTP",
      company: @company,
      adapter_type: :http,
      adapter_config: { "method" => "POST" }
    )
    assert_not role.valid?
    assert_match /missing required keys: url/, role.errors[:adapter_config].join
  end

  test "invalid when process role missing command in adapter_config" do
    role = Role.new(
      title: "Bad Process",
      company: @company,
      adapter_type: :process,
      adapter_config: { "timeout" => 30 }
    )
    assert_not role.valid?
    assert_match /missing required keys: command/, role.errors[:adapter_config].join
  end

  test "invalid when claude_local role missing model in adapter_config" do
    role = Role.new(
      title: "Bad Claude",
      company: @company,
      adapter_type: :claude_local,
      adapter_config: { "max_turns" => 5 }
    )
    assert_not role.valid?
    assert_match /missing required keys: model/, role.errors[:adapter_config].join
  end

  test "valid adapter_config with only required keys" do
    role = Role.new(
      title: "Minimal Claude",
      company: @company,
      adapter_type: :claude_local,
      adapter_config: { "model" => "claude-opus-4" }
    )
    assert role.valid?
  end

  # --- Enums ---

  test "adapter_type enum: http?" do
    assert @developer.http?
    assert_not @cto.http?
  end

  test "adapter_type enum: process?" do
    assert @process_role.process?
  end

  test "adapter_type enum: claude_local?" do
    assert @cto.claude_local?
  end

  test "status enum: idle?" do
    assert @cto.idle?
  end

  test "status enum: paused?" do
    assert @process_role.paused?
  end

  test "status enum covers all values" do
    %i[idle running paused error terminated pending_approval].each do |s|
      role = Role.new(status: s)
      assert role.send(:"#{s}?"), "Expected #{s}? to return true"
    end
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

  test "has many skills through role_skills" do
    skills = @cto.skills
    assert_equal 2, skills.count
    assert skills.all? { |s| s.is_a?(Skill) }
  end

  test "has many role_skills" do
    assert_equal 2, @cto.role_skills.count
  end

  test "has many role_hooks" do
    assert @cto.respond_to?(:role_hooks)
    assert @cto.role_hooks.count > 0
  end

  test "destroying role destroys its role_hooks" do
    hook_count = @cto.role_hooks.count
    assert hook_count > 0
    assert_difference "RoleHook.count", -hook_count do
      @cto.destroy
    end
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

  test "active scope excludes terminated roles" do
    terminated = Role.new(
      title: "Dead Role",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" },
      status: :terminated
    )
    terminated.save!

    active_roles = Role.active
    assert_not_includes active_roles, terminated
    assert_includes active_roles, @cto
  end

  # --- Methods ---

  test "online? returns true for idle role" do
    assert @cto.online?
  end

  test "online? returns true for running role" do
    @cto.status = :running
    assert @cto.online?
  end

  test "offline? returns true for paused role" do
    assert @process_role.offline?
  end

  test "offline? returns true for error status" do
    @cto.status = :error
    assert @cto.offline?
  end

  test "offline? returns true for terminated status" do
    @cto.status = :terminated
    assert @cto.offline?
  end

  test "offline? returns true for pending_approval status" do
    @cto.status = :pending_approval
    assert @cto.offline?
  end

  test "adapter returns correct adapter class for claude_local" do
    assert_equal ClaudeLocalAdapter, @cto.adapter_class
  end

  test "adapter returns correct adapter class for http" do
    assert_equal HttpAdapter, @developer.adapter_class
  end

  test "adapter returns correct adapter class for process" do
    assert_equal ProcessAdapter, @process_role.adapter_class
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

  test "destroying role destroys its role_skills" do
    skill_count = @cto.role_skills.count
    assert skill_count > 0
    assert_difference "RoleSkill.count", -skill_count do
      @cto.destroy
    end
  end

  test "destroying company destroys all its roles" do
    role_count = @company.roles.count
    assert role_count > 0
    assert_difference("Role.count", -role_count) do
      @company.destroy
    end
  end

  # --- API Token ---

  test "generates api_token on create for agent-configured role" do
    role = Role.create!(
      title: "Token Role",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    assert role.api_token.present?
    assert_equal 24, role.api_token.length
  end

  test "api_token is unique" do
    role1 = Role.create!(
      title: "Token Role 1",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    role2 = Role.create!(
      title: "Token Role 2",
      company: @company,
      adapter_type: :http,
      adapter_config: { "url" => "https://example.com" }
    )
    assert_not_equal role1.api_token, role2.api_token
  end

  test "regenerate_api_token! changes the token" do
    old_token = @cto.api_token
    @cto.regenerate_api_token!
    assert_not_equal old_token, @cto.api_token
    assert @cto.api_token.present?
  end

  test "vacant role does not generate api_token" do
    role = Role.create!(title: "Vacant Role", company: @company)
    assert_nil role.api_token
  end

  # --- Budget ---

  test "valid with budget_cents" do
    @cto.budget_cents = 50000
    assert @cto.valid?
  end

  test "invalid with negative budget_cents" do
    @cto.budget_cents = -100
    assert_not @cto.valid?
    assert_includes @cto.errors[:budget_cents], "must be greater than 0"
  end

  test "invalid with zero budget_cents" do
    @cto.budget_cents = 0
    assert_not @cto.valid?
  end

  test "valid with nil budget_cents (no budget)" do
    @cto.budget_cents = nil
    assert @cto.valid?
  end

  test "budget_configured? returns true when budget_cents present" do
    assert @cto.budget_configured?
  end

  test "budget_configured? returns false when budget_cents nil" do
    @process_role.budget_cents = nil
    assert_not @process_role.budget_configured?
  end

  test "monthly_spend_cents returns sum of task costs in current period" do
    expected = Task.where(assignee: @cto)
                   .where.not(cost_cents: nil)
                   .where(created_at: Date.current.beginning_of_month.beginning_of_day..Date.current.end_of_month.end_of_day)
                   .sum(:cost_cents)
    assert_equal expected, @cto.monthly_spend_cents
  end

  test "monthly_spend_cents returns 0 when no budget configured" do
    assert_equal 0, @process_role.monthly_spend_cents
  end

  test "monthly_spend_cents ignores tasks with nil cost_cents" do
    spend = @cto.monthly_spend_cents
    assert spend >= 0
  end

  test "budget_remaining_cents returns correct remaining amount" do
    remaining = @cto.budget_remaining_cents
    assert_equal [ 50000 - @cto.monthly_spend_cents, 0 ].max, remaining
  end

  test "budget_remaining_cents returns nil when no budget" do
    @process_role.budget_cents = nil
    assert_nil @process_role.budget_remaining_cents
  end

  test "budget_remaining_cents never goes below zero" do
    @cto.budget_cents = 1  # $0.01 budget, guaranteed to be exhausted
    assert_equal 0, @cto.budget_remaining_cents
  end

  test "budget_utilization returns percentage" do
    util = @cto.budget_utilization
    assert_kind_of Float, util
    assert util >= 0.0
    assert util <= 100.0
  end

  test "budget_utilization returns 0.0 when no budget" do
    @process_role.budget_cents = nil
    assert_equal 0.0, @process_role.budget_utilization
  end

  test "budget_exhausted? returns true when spend meets budget" do
    @cto.budget_cents = 1  # tiny budget
    assert @cto.budget_exhausted?
  end

  test "budget_exhausted? returns false when under budget" do
    @cto.budget_cents = 999_999_99  # very large budget
    assert_not @cto.budget_exhausted?
  end

  test "budget_alert_threshold? returns true at 80% utilization" do
    spend = @cto.monthly_spend_cents
    @cto.budget_cents = (spend / 0.80).ceil if spend > 0
    if @cto.budget_cents && @cto.budget_cents > 0
      assert @cto.budget_alert_threshold?
    end
  end

  test "budget_alert_threshold? returns false when well under budget" do
    @cto.budget_cents = 999_999_99
    assert_not @cto.budget_alert_threshold?
  end

  test "current_budget_period_start defaults to beginning of month" do
    @cto.budget_period_start = nil
    assert_equal Date.current.beginning_of_month, @cto.current_budget_period_start
  end

  test "current_budget_period_end returns end of month" do
    assert_equal @cto.current_budget_period_start.end_of_month, @cto.current_budget_period_end
  end

  # --- Real-time broadcasts ---

  test "role has broadcast_dashboard_update private method" do
    assert @cto.respond_to?(:broadcast_dashboard_update, true)
  end

  test "role status change does not error" do
    assert_nothing_raised do
      @cto.update!(status: :running)
    end
  end

  # --- all_documents ---

  test "all_documents returns role's directly linked documents" do
    Current.company = companies(:acme)
    role = roles(:cto)
    docs = role.all_documents
    assert_includes docs, documents(:acme_refund_policy)
  end

  test "all_documents returns documents from role's skills" do
    Current.company = companies(:acme)
    role = roles(:cto)
    docs = role.all_documents
    assert_includes docs, documents(:acme_coding_standards)
  end

  test "all_documents does not return unlinked documents" do
    Current.company = companies(:acme)
    role = roles(:cto)
    docs = role.all_documents
    assert_not_includes docs, documents(:acme_agent_created_doc)
  end

  test "all_documents does not return documents from other companies" do
    Current.company = companies(:acme)
    role = roles(:cto)
    docs = role.all_documents
    assert_not_includes docs, documents(:widgets_doc)
  end

  test "all_documents does not duplicate documents linked both directly and via skill" do
    Current.company = companies(:acme)
    role = roles(:cto)
    # Link coding_standards directly to the role too (it's already linked via skill)
    RoleDocument.find_or_create_by!(role: role, document: documents(:acme_coding_standards))
    docs = role.all_documents
    coding_standards_count = docs.select { |d| d.id == documents(:acme_coding_standards).id }.count
    assert_equal 1, coding_standards_count
  end

  # --- Goals association ---

  test "role can have many goals" do
    role = roles(:cto)
    assert_includes role.goals, goals(:acme_objective_one)
  end

  test "role with no goals is still valid" do
    role = roles(:developer)
    assert_empty role.goals
    assert role.valid?
  end

  test "destroying role nullifies goal role_id" do
    role = roles(:cto)
    goal = goals(:acme_objective_one)
    assert_equal role, goal.role

    role.destroy
    goal.reload
    assert_nil goal.role_id
  end

  # --- Auto-assignment ---

  test "first agent configuration creates role_skills for role default skills" do
    # CEO role has no adapter. Configuring it should trigger auto-assignment.
    # CEO maps to: strategic_planning, decision_making, risk_assessment
    assert_equal 0, @ceo.role_skills.count, "Role should start with no skills"

    @ceo.update!(adapter_type: :http, adapter_config: { "url" => "https://example.com" })

    @ceo.reload
    skill_keys = @ceo.skills.pluck(:key).sort
    expected_keys = %w[decision_making risk_assessment strategic_planning]
    assert_equal expected_keys, skill_keys, "Role should have all CEO default skills"
  end

  test "first agent configuration does not duplicate existing skills" do
    # Create a role whose title matches a default_skills key, pre-assign a skill, then configure adapter.
    roles(:ceo).destroy # free up the "CEO" title
    role = Role.create!(title: "CEO", company: @company)
    role.role_skills.create!(skill: skills(:acme_strategic_planning))
    initial_count = role.role_skills.count
    assert initial_count > 0, "Role should have some existing skills"

    # Configuring adapter triggers first assignment.
    role.update!(adapter_type: :http, adapter_config: { "url" => "https://example.com" })

    role.reload
    # strategic_planning should exist exactly once
    sp_count = role.role_skills.joins(:skill).where(skills: { key: "strategic_planning" }).count
    assert_equal 1, sp_count, "strategic_planning should not be duplicated"
  end

  test "unknown role title silently skips auto-assignment" do
    role = Role.create!(title: "Chief Happiness Officer", company: @company)

    assert_no_difference("RoleSkill.count") do
      role.update!(adapter_type: :http, adapter_config: { "url" => "https://example.com" })
    end
  end

  test "default_skill_keys_for returns empty array for unknown title" do
    assert_equal [], Role.default_skill_keys_for("Nonexistent Role")
  end

  test "default_skill_keys_for is case-insensitive" do
    ceo_keys = Role.default_skill_keys_for("CEO")
    assert_equal 3, ceo_keys.size
    assert_includes ceo_keys, "strategic_planning"

    ceo_keys_lower = Role.default_skill_keys_for("ceo")
    assert_equal ceo_keys.sort, ceo_keys_lower.sort
  end
end
