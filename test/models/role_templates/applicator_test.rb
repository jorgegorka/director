require "test_helper"

class RoleTemplates::ApplicatorTest < ActiveSupport::TestCase
  # widgets project is nearly clean (only Operations Lead role) -- used for clean hierarchy tests
  # acme project has CEO, CTO, Senior Developer, Script Runner -- used for skip-duplicate tests

  setup do
    projects(:widgets).seed_default_role_categories!
  end

  teardown do
    RoleTemplates::Registry.reset!
  end

  # --- Hierarchy creation (APPLY-01) ---

  test "creates full marketing hierarchy with correct parent-child relationships" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_equal 9, result.created
    cmo     = project.roles.find_by!(title: "CMO")
    planner = project.roles.find_by!(title: "Marketing Planner")
    analyst = project.roles.find_by!(title: "Web Analyst")
    seo     = project.roles.find_by!(title: "SEO Specialist")
    manager = project.roles.find_by!(title: "Marketing Manager")

    assert_nil cmo.parent_id, "CMO should have no parent"
    assert_equal cmo, planner.parent
    assert_equal planner, analyst.parent
    assert_equal planner, seo.parent
    assert_equal cmo, manager.parent
  end

  test "creates roles in dependency order -- parents exist before children" do
    project = projects(:widgets)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    cmo     = project.roles.find_by!(title: "CMO")
    planner = project.roles.find_by!(title: "Marketing Planner")
    analyst = project.roles.find_by!(title: "Web Analyst")
    manager = project.roles.find_by!(title: "Marketing Manager")

    assert planner.parent.id < planner.id, "CMO should have lower id than Marketing Planner"
    assert analyst.parent.id < analyst.id, "Marketing Planner should have lower id than Web Analyst"
    assert manager.parent.id < manager.id, "CMO should have lower id than Marketing Manager"
  end

  test "root role has nil parent when no parent_role provided" do
    project = projects(:widgets)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    cmo = project.roles.find_by!(title: "CMO")
    assert_nil cmo.parent_id
  end

  test "root role is nested under parent_role when provided" do
    project = projects(:widgets)
    orchestrator = project.role_categories.find_by!(name: "Orchestrator")
    ceo = project.roles.create!(title: "CEO", description: "Chief Executive", role_category: orchestrator)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing", parent_role: ceo)

    assert result.success?
    # CMO is the marketing template root — should be nested under the provided parent
    cmo = project.roles.find_by!(title: "CMO")
    assert_equal ceo.id, cmo.parent_id
  end

  # --- Skip duplicate (APPLY-02) ---

  test "applying same template twice creates no new roles on second run" do
    project = projects(:widgets)
    first  = RoleTemplates::Applicator.call(project: project, template_key: "marketing")
    second = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_equal 9, first.created
    assert_equal 0, second.created
    assert_equal 9, second.skipped
  end

  test "skip-duplicate is case-sensitive with default SQLite column (no COLLATE NOCASE)" do
    project = projects(:widgets)
    orchestrator = project.role_categories.find_by!(name: "Orchestrator")
    project.roles.create!(title: "cmo", description: "lowercase cmo", role_category: orchestrator)

    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert project.roles.exists?(title: "CMO"),
      "CMO (uppercase) should be created because find_by is case-sensitive"
    assert_equal 2, project.roles.where("lower(title) = 'cmo'").count,
      "Both 'cmo' and 'CMO' should exist (case-sensitive storage)"
  end

  # --- Skill pre-assignment (APPLY-03) ---

  test "does not assign skills from another project" do
    project = projects(:widgets)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    acme = projects(:acme)
    new_roles = project.roles.where(title: %w[CMO Marketing\ Planner Web\ Analyst SEO\ Specialist Marketing\ Manager])

    new_roles.each do |role|
      role.skills.each do |skill|
        assert_equal project.id, skill.project_id,
          "Role '#{role.title}' should only have skills from widgets project"
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

  test "handles missing skills gracefully -- no error if skill key not in project" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert result.success?, "Should succeed even when skill keys don't match project skills"
    assert_equal 9, result.created
  end

  # --- Result object (APPLY-04) ---

  test "result reports correct created count" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_equal 9, result.created
  end

  test "result reports correct skipped count" do
    project = projects(:widgets)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing")
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_equal 9, result.skipped
  end

  test "result success? returns true when no errors" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert result.success?
  end

  test "result summary returns human-readable string" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_includes result.summary, "Created 9 roles"
  end

  test "result summary includes skipped when applicable" do
    project = projects(:widgets)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing")
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_includes result.summary, "Skipped"
  end

  test "result created_roles contains the actual Role records" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_equal 9, result.created_roles.size
    result.created_roles.each do |role|
      assert_kind_of Role, role
      assert role.persisted?
    end
  end

  test "result total equals created plus skipped" do
    project = projects(:widgets)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing")
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert_equal result.created + result.skipped, result.total
  end

  test "result errors list is frozen" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert result.errors.frozen?
  end

  test "result created_roles list is frozen" do
    project = projects(:widgets)
    result = RoleTemplates::Applicator.call(project: project, template_key: "marketing")

    assert result.created_roles.frozen?
  end

  # --- parent_role parameter ---

  test "parent_role nests template root under specified role" do
    project = projects(:widgets)
    orchestrator = project.role_categories.find_by!(name: "Orchestrator")
    ceo = project.roles.create!(title: "CEO", description: "Chief Executive", role_category: orchestrator)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing", parent_role: ceo)

    cmo = project.roles.find_by!(title: "CMO")
    assert_equal ceo.id, cmo.parent_id
  end

  test "parent_role nil leaves template root as root" do
    project = projects(:widgets)
    RoleTemplates::Applicator.call(project: project, template_key: "marketing", parent_role: nil)

    cmo = project.roles.find_by!(title: "CMO")
    assert_nil cmo.parent_id
  end

  # --- Cross-tenant isolation ---

  test "does not create roles in wrong project" do
    acme_role_count_before = projects(:acme).roles.count
    RoleTemplates::Applicator.call(project: projects(:widgets), template_key: "marketing")

    assert_equal acme_role_count_before, projects(:acme).roles.count,
      "Applying template to widgets should not create roles in acme"
  end

  # --- Error handling ---

  test "raises TemplateNotFound for invalid template key" do
    project = projects(:widgets)
    assert_raises(RoleTemplates::Registry::TemplateNotFound) do
      RoleTemplates::Applicator.call(project: project, template_key: "nonexistent_template")
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
