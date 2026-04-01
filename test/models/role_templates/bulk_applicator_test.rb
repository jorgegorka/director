require "test_helper"

class RoleTemplates::BulkApplicatorTest < ActiveSupport::TestCase
  # widgets company: 1 role ("Operations Lead") -- used for clean-slate tests
  # acme company: CEO, CTO, Senior Developer, Script Runner -- used for partial overlap tests

  teardown do
    RoleTemplates::Registry.reset!
  end

  # --- Full company creation ---

  test "creates all template roles on clean company" do
    company = companies(:widgets)
    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    assert_difference "company.roles.count", expected_template_roles do
      RoleTemplates::BulkApplicator.call(company: company)
    end
  end

  test "result created count matches actual new roles created" do
    company = companies(:widgets)
    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }

    result = RoleTemplates::BulkApplicator.call(company: company)

    assert_equal expected_template_roles, result.created
  end

  test "marketing hierarchy is correct" do
    company = companies(:widgets)
    RoleTemplates::BulkApplicator.call(company: company)

    ceo     = company.roles.find_by!(title: "CEO")
    cmo     = company.roles.find_by!(title: "CMO")
    planner = company.roles.find_by!(title: "Marketing Planner")
    analyst = company.roles.find_by!(title: "Web Analyst")
    seo     = company.roles.find_by!(title: "SEO Specialist")
    manager = company.roles.find_by!(title: "Marketing Manager")

    assert_nil ceo.parent_id
    assert_equal ceo, cmo.parent
    assert_equal cmo, planner.parent
    assert_equal planner, analyst.parent
    assert_equal planner, seo.parent
    assert_equal cmo, manager.parent
  end

  # --- Idempotency ---

  test "applying all twice creates no duplicates" do
    company = companies(:widgets)
    first = RoleTemplates::BulkApplicator.call(company: company)
    role_count_after_first = company.roles.count

    second = RoleTemplates::BulkApplicator.call(company: company)

    assert_equal role_count_after_first, company.roles.count,
      "Second apply all should not create any new roles"
    assert_equal 0, second.created,
      "Second result created should be 0"
  end

  test "second apply all skips all roles" do
    company = companies(:widgets)
    first = RoleTemplates::BulkApplicator.call(company: company)

    second = RoleTemplates::BulkApplicator.call(company: company)

    assert_equal first.total, second.skipped,
      "Second call should skip exactly as many roles as the first call created+skipped"
  end

  # --- Combined result ---

  test "result aggregates created count from all templates" do
    company = companies(:widgets)
    result = RoleTemplates::BulkApplicator.call(company: company)

    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    assert_equal expected_template_roles, result.created
  end

  test "result aggregates skipped count from all templates" do
    company = companies(:widgets)
    RoleTemplates::BulkApplicator.call(company: company)

    result = RoleTemplates::BulkApplicator.call(company: company)

    expected_total = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    assert_equal expected_total, result.skipped
  end

  test "result success? is true when all templates succeed" do
    company = companies(:widgets)
    result = RoleTemplates::BulkApplicator.call(company: company)

    assert result.success?
  end

  test "result summary describes total created" do
    company = companies(:widgets)
    result = RoleTemplates::BulkApplicator.call(company: company)

    assert_not_empty result.summary
    assert_includes result.summary, "Created"
  end

  test "result created_roles contains all newly created Role records" do
    company = companies(:widgets)
    result = RoleTemplates::BulkApplicator.call(company: company)

    assert_equal result.created, result.created_roles.size
    result.created_roles.each do |role|
      assert_kind_of Role, role
      assert role.persisted?
    end
  end

  test "result created_roles list is frozen" do
    company = companies(:widgets)
    result = RoleTemplates::BulkApplicator.call(company: company)

    assert result.created_roles.frozen?
  end

  test "result errors list is frozen" do
    company = companies(:widgets)
    result = RoleTemplates::BulkApplicator.call(company: company)

    assert result.errors.frozen?
  end

  # --- Cross-tenant isolation ---

  test "does not affect other companies" do
    acme_count_before = companies(:acme).roles.count
    RoleTemplates::BulkApplicator.call(company: companies(:widgets))

    assert_equal acme_count_before, companies(:acme).roles.count,
      "Applying all templates to widgets should not create roles in acme"
  end
end
