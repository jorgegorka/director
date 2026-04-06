require "test_helper"

class RoleTemplates::BulkApplicatorTest < ActiveSupport::TestCase
  # widgets project: 1 role ("Operations Lead") -- used for clean-slate tests
  # acme project: CEO, CTO, Senior Developer, Script Runner -- used for partial overlap tests

  setup do
    projects(:widgets).seed_default_role_categories!
  end

  teardown do
    RoleTemplates::Registry.reset!
  end

  # --- Full project creation ---

  test "creates all template roles on clean project" do
    project = projects(:widgets)
    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    assert_difference "project.roles.count", expected_template_roles do
      RoleTemplates::BulkApplicator.call(project: project)
    end
  end

  test "result created count matches actual new roles created" do
    project = projects(:widgets)
    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }

    result = RoleTemplates::BulkApplicator.call(project: project)

    assert_equal expected_template_roles, result.created
  end

  test "marketing hierarchy is correct" do
    project = projects(:widgets)
    RoleTemplates::BulkApplicator.call(project: project)

    ceo     = project.roles.find_by!(title: "CEO")
    cmo     = project.roles.find_by!(title: "CMO")
    planner = project.roles.find_by!(title: "Marketing Planner")
    analyst = project.roles.find_by!(title: "Web Analyst")
    seo     = project.roles.find_by!(title: "SEO Specialist")
    manager = project.roles.find_by!(title: "Marketing Manager")

    assert_nil ceo.parent_id
    assert_equal ceo, cmo.parent
    assert_equal cmo, planner.parent
    assert_equal planner, analyst.parent
    assert_equal planner, seo.parent
    assert_equal cmo, manager.parent
  end

  # --- Idempotency ---

  test "applying all twice creates no duplicates" do
    project = projects(:widgets)
    first = RoleTemplates::BulkApplicator.call(project: project)
    role_count_after_first = project.roles.count

    second = RoleTemplates::BulkApplicator.call(project: project)

    assert_equal role_count_after_first, project.roles.count,
      "Second apply all should not create any new roles"
    assert_equal 0, second.created,
      "Second result created should be 0"
  end

  test "second apply all skips all roles" do
    project = projects(:widgets)
    first = RoleTemplates::BulkApplicator.call(project: project)

    second = RoleTemplates::BulkApplicator.call(project: project)

    assert_equal first.total, second.skipped,
      "Second call should skip exactly as many roles as the first call created+skipped"
  end

  # --- Combined result ---

  test "result aggregates created count from all templates" do
    project = projects(:widgets)
    result = RoleTemplates::BulkApplicator.call(project: project)

    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    assert_equal expected_template_roles, result.created
  end

  test "result aggregates skipped count from all templates" do
    project = projects(:widgets)
    RoleTemplates::BulkApplicator.call(project: project)

    result = RoleTemplates::BulkApplicator.call(project: project)

    expected_total = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    assert_equal expected_total, result.skipped
  end

  test "result success? is true when all templates succeed" do
    project = projects(:widgets)
    result = RoleTemplates::BulkApplicator.call(project: project)

    assert result.success?
  end

  test "result summary describes total created" do
    project = projects(:widgets)
    result = RoleTemplates::BulkApplicator.call(project: project)

    assert_not_empty result.summary
    assert_includes result.summary, "Created"
  end

  test "result created_roles contains all newly created Role records" do
    project = projects(:widgets)
    result = RoleTemplates::BulkApplicator.call(project: project)

    assert_equal result.created, result.created_roles.size
    result.created_roles.each do |role|
      assert_kind_of Role, role
      assert role.persisted?
    end
  end

  test "result created_roles list is frozen" do
    project = projects(:widgets)
    result = RoleTemplates::BulkApplicator.call(project: project)

    assert result.created_roles.frozen?
  end

  test "result errors list is frozen" do
    project = projects(:widgets)
    result = RoleTemplates::BulkApplicator.call(project: project)

    assert result.errors.frozen?
  end

  # --- Cross-tenant isolation ---

  test "does not affect other projects" do
    acme_count_before = projects(:acme).roles.count
    RoleTemplates::BulkApplicator.call(project: projects(:widgets))

    assert_equal acme_count_before, projects(:acme).roles.count,
      "Applying all templates to widgets should not create roles in acme"
  end
end
