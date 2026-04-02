require "test_helper"

class RoleTemplates::ApplicatorTest < ActiveSupport::TestCase
  # widgets company is nearly clean (only Operations Lead role) -- used for clean hierarchy tests
  # acme company has CEO, CTO, Senior Developer, Script Runner -- used for skip-duplicate tests

  setup do
    companies(:widgets).seed_default_role_categories!
  end

  teardown do
    RoleTemplates::Registry.reset!
  end

  # --- Hierarchy creation (APPLY-01) ---

  test "creates full marketing hierarchy with correct parent-child relationships" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_equal 10, result.created
    ceo     = company.roles.find_by!(title: "CEO")
    cmo     = company.roles.find_by!(title: "CMO")
    planner = company.roles.find_by!(title: "Marketing Planner")
    analyst = company.roles.find_by!(title: "Web Analyst")
    seo     = company.roles.find_by!(title: "SEO Specialist")
    manager = company.roles.find_by!(title: "Marketing Manager")

    assert_nil ceo.parent_id, "CEO should have no parent"
    assert_equal ceo, cmo.parent
    assert_equal cmo, planner.parent
    assert_equal planner, analyst.parent
    assert_equal planner, seo.parent
    assert_equal cmo, manager.parent
  end

  test "creates roles in dependency order -- parents exist before children" do
    company = companies(:widgets)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    cmo     = company.roles.find_by!(title: "CMO")
    planner = company.roles.find_by!(title: "Marketing Planner")
    analyst = company.roles.find_by!(title: "Web Analyst")
    manager = company.roles.find_by!(title: "Marketing Manager")

    assert planner.parent.id < planner.id, "CMO should have lower id than Marketing Planner"
    assert analyst.parent.id < analyst.id, "Marketing Planner should have lower id than Web Analyst"
    assert manager.parent.id < manager.id, "CMO should have lower id than Marketing Manager"
  end

  test "root role has nil parent when no parent_role provided" do
    company = companies(:widgets)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    ceo = company.roles.find_by!(title: "CEO")
    assert_nil ceo.parent_id
  end

  test "root role is nested under parent_role when provided" do
    company = companies(:widgets)
    orchestrator = company.role_categories.find_by!(name: "Orchestrator")
    ceo = company.roles.create!(title: "CEO", description: "Chief Executive", role_category: orchestrator)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing", parent_role: ceo)

    assert result.success?
    cmo = company.roles.find_by!(title: "CMO")
    assert_equal ceo, cmo.parent
  end

  # --- Skip duplicate (APPLY-02) ---

  test "applying same template twice creates no new roles on second run" do
    company = companies(:widgets)
    first  = RoleTemplates::Applicator.call(company: company, template_key: "marketing")
    second = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_equal 10, first.created
    assert_equal 0, second.created
    assert_equal 10, second.skipped
  end

  test "skip-duplicate is case-sensitive with default SQLite column (no COLLATE NOCASE)" do
    company = companies(:widgets)
    orchestrator = company.role_categories.find_by!(name: "Orchestrator")
    company.roles.create!(title: "cmo", description: "lowercase cmo", role_category: orchestrator)

    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert company.roles.exists?(title: "CMO"),
      "CMO (uppercase) should be created because find_by is case-sensitive"
    assert_equal 2, company.roles.where("lower(title) = 'cmo'").count,
      "Both 'cmo' and 'CMO' should exist (case-sensitive storage)"
  end

  # --- Skill pre-assignment (APPLY-03) ---

  test "does not assign skills from another company" do
    company = companies(:widgets)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    acme = companies(:acme)
    new_roles = company.roles.where(title: %w[CMO Marketing\ Planner Web\ Analyst SEO\ Specialist Marketing\ Manager])

    new_roles.each do |role|
      role.skills.each do |skill|
        assert_equal company.id, skill.company_id,
          "Role '#{role.title}' should only have skills from widgets company"
      end
    end

    acme_skill_ids = acme.skills.pluck(:id)
    widgets_role_skill_count_from_acme = RoleSkill.where(
      role_id: new_roles.pluck(:id),
      skill_id: acme_skill_ids
    ).count
    assert_equal 0, widgets_role_skill_count_from_acme,
      "No widgets role should have skills from acme"
  end

  test "handles missing skills gracefully -- no error if skill key not in company" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert result.success?, "Should succeed even when skill keys don't match company skills"
    assert_equal 10, result.created
  end

  # --- Result object (APPLY-04) ---

  test "result reports correct created count" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_equal 10, result.created
  end

  test "result reports correct skipped count" do
    company = companies(:widgets)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing")
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_equal 10, result.skipped
  end

  test "result success? returns true when no errors" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert result.success?
  end

  test "result summary returns human-readable string" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_includes result.summary, "Created 10 roles"
  end

  test "result summary includes skipped when applicable" do
    company = companies(:widgets)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing")
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_includes result.summary, "Skipped"
  end

  test "result created_roles contains the actual Role records" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_equal 10, result.created_roles.size
    result.created_roles.each do |role|
      assert_kind_of Role, role
      assert role.persisted?
    end
  end

  test "result total equals created plus skipped" do
    company = companies(:widgets)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing")
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert_equal result.created + result.skipped, result.total
  end

  test "result errors list is frozen" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert result.errors.frozen?
  end

  test "result created_roles list is frozen" do
    company = companies(:widgets)
    result = RoleTemplates::Applicator.call(company: company, template_key: "marketing")

    assert result.created_roles.frozen?
  end

  # --- parent_role parameter ---

  test "parent_role nests template root under specified role" do
    company = companies(:widgets)
    orchestrator = company.role_categories.find_by!(name: "Orchestrator")
    ceo = company.roles.create!(title: "CEO", description: "Chief Executive", role_category: orchestrator)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing", parent_role: ceo)

    cmo = company.roles.find_by!(title: "CMO")
    assert_equal ceo.id, cmo.parent_id
  end

  test "parent_role nil leaves template root as root" do
    company = companies(:widgets)
    RoleTemplates::Applicator.call(company: company, template_key: "marketing", parent_role: nil)

    ceo = company.roles.find_by!(title: "CEO")
    assert_nil ceo.parent_id
  end

  # --- Cross-tenant isolation ---

  test "does not create roles in wrong company" do
    acme_role_count_before = companies(:acme).roles.count
    RoleTemplates::Applicator.call(company: companies(:widgets), template_key: "marketing")

    assert_equal acme_role_count_before, companies(:acme).roles.count,
      "Applying template to widgets should not create roles in acme"
  end

  # --- Error handling ---

  test "raises TemplateNotFound for invalid template key" do
    company = companies(:widgets)
    assert_raises(RoleTemplates::Registry::TemplateNotFound) do
      RoleTemplates::Applicator.call(company: company, template_key: "nonexistent_template")
    end
  end

  test "result summary is empty string when nothing happened" do
    result = RoleTemplates::Applicator::Result.new(created: 0, skipped: 0, errors: [], created_roles: [])
    assert_equal "", result.summary
  end

  # --- Summary method edge cases ---

  test "result summary pluralizes role correctly for single role" do
    result = RoleTemplates::Applicator::Result.new(created: 1, skipped: 0, errors: [], created_roles: [])
    assert_includes result.summary, "Created 1 role"
    assert_not_includes result.summary, "roles"
  end

  test "result summary pluralizes error correctly for single error" do
    result = RoleTemplates::Applicator::Result.new(created: 0, skipped: 0, errors: [ "oops" ], created_roles: [])
    assert_includes result.summary, "1 error"
    assert_not_includes result.summary, "errors"
  end
end
