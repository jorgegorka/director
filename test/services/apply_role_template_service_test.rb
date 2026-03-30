require "test_helper"

class ApplyRoleTemplateServiceTest < ActiveSupport::TestCase
  # widgets company is nearly clean (only Operations Lead role) -- used for clean hierarchy tests
  # acme company has CEO, CTO, Senior Developer, Script Runner -- used for skip-duplicate tests

  teardown do
    RoleTemplateRegistry.reset!
  end

  # --- Hierarchy creation (APPLY-01) ---

  test "creates full engineering hierarchy with correct parent-child relationships" do
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_equal 5, result.created
    cto = company.roles.find_by!(title: "CTO")
    vp  = company.roles.find_by!(title: "VP Engineering")
    tl  = company.roles.find_by!(title: "Tech Lead")
    eng = company.roles.find_by!(title: "Engineer")
    qa  = company.roles.find_by!(title: "QA")

    assert_nil cto.parent_id, "CTO should have no parent"
    assert_equal cto, vp.parent
    assert_equal vp, tl.parent
    assert_equal tl, eng.parent
    assert_equal vp, qa.parent
  end

  test "creates roles in dependency order -- parents exist before children" do
    company = companies(:widgets)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    vp  = company.roles.find_by!(title: "VP Engineering")
    tl  = company.roles.find_by!(title: "Tech Lead")
    eng = company.roles.find_by!(title: "Engineer")
    qa  = company.roles.find_by!(title: "QA")

    assert vp.parent.id < vp.id, "CTO should have lower id than VP Engineering"
    assert tl.parent.id < tl.id, "VP Engineering should have lower id than Tech Lead"
    assert eng.parent.id < eng.id, "Tech Lead should have lower id than Engineer"
    assert qa.parent.id < qa.id, "VP Engineering should have lower id than QA"
  end

  test "root role has nil parent when no parent_role provided" do
    company = companies(:widgets)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    cto = company.roles.find_by!(title: "CTO")
    assert_nil cto.parent_id
  end

  test "root role is nested under parent_role when provided" do
    company = companies(:widgets)
    ceo = company.roles.create!(title: "CEO", description: "Chief Executive")
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering", parent_role: ceo)

    assert result.success?
    cto = company.roles.find_by!(title: "CTO")
    assert_equal ceo, cto.parent
  end

  # --- Skip duplicate (APPLY-02) ---

  test "skips roles whose title already exists in company" do
    # acme already has a CTO role
    company = companies(:acme)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert result.skipped >= 1
    assert_equal 1, company.roles.where(title: "CTO").count, "Should not create duplicate CTO"
  end

  test "applying same template twice creates no new roles on second run" do
    company = companies(:widgets)
    first  = ApplyRoleTemplateService.call(company: company, template_key: "engineering")
    second = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_equal 5, first.created
    assert_equal 0, second.created
    assert_equal 5, second.skipped
  end

  test "children of skipped roles still get correct parent" do
    # acme has CTO already; VP Engineering should be parented to existing CTO
    company = companies(:acme)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    existing_cto = company.roles.find_by!(title: "CTO")
    vp = company.roles.find_by!(title: "VP Engineering")

    assert_equal existing_cto, vp.parent
  end

  test "skip-duplicate is case-sensitive with default SQLite column (no COLLATE NOCASE)" do
    # The roles table title column has no COLLATE NOCASE annotation.
    # find_by(title:) therefore does a case-sensitive match.
    # Creating "cto" (lowercase) does NOT block creation of "CTO" (uppercase).
    company = companies(:widgets)
    company.roles.create!(title: "cto", description: "lowercase cto")

    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    # "cto" != "CTO" in SQLite without COLLATE NOCASE, so CTO from template is created
    assert company.roles.exists?(title: "CTO"),
      "CTO (uppercase) should be created because find_by is case-sensitive"
    assert_equal 2, company.roles.where("lower(title) = 'cto'").count,
      "Both 'cto' and 'CTO' should exist (case-sensitive storage)"
  end

  # --- Skill pre-assignment (APPLY-03) ---

  test "assigns skills from company skill library to created roles" do
    # acme has code_review, architecture_planning, technical_strategy, system_design, security_assessment
    # These overlap with CTO's skill_keys in the engineering template
    company = companies(:acme)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    # VP Engineering was not in acme (no VP Engineering fixture) -- check its skills
    vp = company.roles.find_by(title: "VP Engineering")
    if vp
      assigned_keys = vp.skills.pluck(:key)
      # project_planning is in engineering template skill_keys for VP Engineering
      # and acme has project_planning skill in fixtures
      assert_includes assigned_keys, "project_planning"
    end
  end

  test "does not assign skills from another company" do
    company = companies(:widgets)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    acme = companies(:acme)
    new_role_titles = %w[CTO VP\ Engineering Tech\ Lead Engineer QA]
    new_roles = company.roles.where(title: new_role_titles)

    # Verify no role has skills belonging to a different company
    new_roles.each do |role|
      role.skills.each do |skill|
        assert_equal company.id, skill.company_id,
          "Role '#{role.title}' should only have skills from widgets company"
      end
    end

    # The key isolation check: acme skills must not appear on widgets roles
    acme_skill_ids = acme.skills.pluck(:id)
    widgets_role_skill_count_from_acme = RoleSkill.where(
      role_id: new_roles.pluck(:id),
      skill_id: acme_skill_ids
    ).count
    assert_equal 0, widgets_role_skill_count_from_acme,
      "No widgets role should have skills from acme"
  end

  test "handles missing skills gracefully -- no error if skill key not in company" do
    # widgets only has strategic_planning skill; engineering template needs code_review etc.
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert result.success?, "Should succeed even when skill keys don't match company skills"
    assert_equal 5, result.created
  end

  # --- Result object (APPLY-04) ---

  test "result reports correct created count" do
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_equal 5, result.created
  end

  test "result reports correct skipped count" do
    company = companies(:widgets)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_equal 5, result.skipped
  end

  test "result success? returns true when no errors" do
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert result.success?
  end

  test "result summary returns human-readable string" do
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_includes result.summary, "Created 5 roles"
  end

  test "result summary includes skipped when applicable" do
    company = companies(:acme)  # has CTO already
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_includes result.summary, "Skipped"
  end

  test "result created_roles contains the actual Role records" do
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_equal 5, result.created_roles.size
    result.created_roles.each do |role|
      assert_kind_of Role, role
      assert role.persisted?
    end
  end

  test "result total equals created plus skipped" do
    company = companies(:acme)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert_equal result.created + result.skipped, result.total
  end

  test "result errors list is frozen" do
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert result.errors.frozen?
  end

  test "result created_roles list is frozen" do
    company = companies(:widgets)
    result = ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    assert result.created_roles.frozen?
  end

  # --- parent_role parameter ---

  test "parent_role nests department root under specified role" do
    company = companies(:widgets)
    ceo = company.roles.create!(title: "CEO", description: "Chief Executive")
    ApplyRoleTemplateService.call(company: company, template_key: "engineering", parent_role: ceo)

    cto = company.roles.find_by!(title: "CTO")
    assert_equal ceo.id, cto.parent_id
  end

  test "parent_role nil leaves department root as root" do
    company = companies(:widgets)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering", parent_role: nil)

    cto = company.roles.find_by!(title: "CTO")
    assert_nil cto.parent_id
  end

  # --- Cross-tenant isolation ---

  test "does not create roles in wrong company" do
    acme_role_count_before = companies(:acme).roles.count
    ApplyRoleTemplateService.call(company: companies(:widgets), template_key: "engineering")

    assert_equal acme_role_count_before, companies(:acme).roles.count,
      "Applying template to widgets should not create roles in acme"
  end

  # --- Error handling ---

  test "raises TemplateNotFound for invalid template key" do
    company = companies(:widgets)
    assert_raises(RoleTemplateRegistry::TemplateNotFound) do
      ApplyRoleTemplateService.call(company: company, template_key: "nonexistent_template")
    end
  end

  test "result summary is empty string when nothing happened" do
    # If somehow 0 created, 0 skipped, 0 errors -- summary should be empty
    result = ApplyRoleTemplateService::Result.new(created: 0, skipped: 0, errors: [], created_roles: [])
    assert_equal "", result.summary
  end

  # --- Idempotency of skill assignment ---

  test "does not create duplicate role_skills on re-application" do
    company = companies(:acme)
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    # Apply again -- skips roles but the pre-existing skills should not be duplicated
    ApplyRoleTemplateService.call(company: company, template_key: "engineering")

    company.roles.each do |role|
      skill_ids = role.role_skills.pluck(:skill_id)
      assert_equal skill_ids.uniq.size, skill_ids.size,
        "Role '#{role.title}' should have no duplicate role_skills"
    end
  end

  # --- Summary method edge cases ---

  test "result summary pluralizes role correctly for single role" do
    result = ApplyRoleTemplateService::Result.new(created: 1, skipped: 0, errors: [], created_roles: [])
    assert_includes result.summary, "Created 1 role"
    assert_not_includes result.summary, "roles"
  end

  test "result summary pluralizes error correctly for single error" do
    result = ApplyRoleTemplateService::Result.new(created: 0, skipped: 0, errors: [ "oops" ], created_roles: [])
    assert_includes result.summary, "1 error"
    assert_not_includes result.summary, "errors"
  end
end
