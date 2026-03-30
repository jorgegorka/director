require "test_helper"

class RoleTemplates::BulkApplicatorTest < ActiveSupport::TestCase
  # widgets company: 1 role ("Operations Lead") -- used for clean-slate full company creation tests
  # acme company: CEO, CTO, Senior Developer, Script Runner -- used for partial overlap and CEO find tests

  teardown do
    RoleTemplates::Registry.reset!
  end

  # --- Full company creation (APPLY-05) ---

  test "creates CEO plus all department roles on empty company" do
    company = companies(:widgets)
    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    # CEO (1) + all template roles
    assert_difference "company.roles.count", 1 + expected_template_roles do
      RoleTemplates::BulkApplicator.call(company: company)
    end
  end

  test "result created count matches actual new roles created" do
    company = companies(:widgets)
    expected_template_roles = RoleTemplates::Registry.all.sum { |t| t.roles.size }
    expected_created = 1 + expected_template_roles # CEO + all template roles

    result = RoleTemplates::BulkApplicator.call(company: company)

    assert_equal expected_created, result.created
  end

  test "all five department roots are children of CEO" do
    company = companies(:widgets)
    RoleTemplates::BulkApplicator.call(company: company)

    ceo = company.roles.find_by!(title: "CEO")
    department_roots = %w[CTO CMO COO CFO HR\ Director]
    department_roots.each do |root_title|
      root = company.roles.find_by!(title: root_title)
      assert_equal ceo, root.parent,
        "Expected #{root_title} parent to be CEO but was #{root.parent&.title.inspect}"
    end
  end

  test "department hierarchies are correct within each department" do
    company = companies(:widgets)
    RoleTemplates::BulkApplicator.call(company: company)

    # Spot-check Engineering hierarchy
    cto = company.roles.find_by!(title: "CTO")
    vp  = company.roles.find_by!(title: "VP Engineering")
    tl  = company.roles.find_by!(title: "Tech Lead")
    eng = company.roles.find_by!(title: "Engineer")
    qa  = company.roles.find_by!(title: "QA")

    assert_equal cto, vp.parent
    assert_equal vp, tl.parent
    assert_equal tl, eng.parent
    assert_equal vp, qa.parent
  end

  # --- CEO find-or-create ---

  test "creates CEO when none exists" do
    company = companies(:widgets)
    assert_nil company.roles.find_by(title: "CEO"), "widgets should start with no CEO"

    RoleTemplates::BulkApplicator.call(company: company)

    ceo = company.roles.find_by(title: "CEO")
    assert_not_nil ceo, "CEO should be created"
  end

  test "CEO has meaningful description and job_spec" do
    company = companies(:widgets)
    RoleTemplates::BulkApplicator.call(company: company)

    ceo = company.roles.find_by!(title: "CEO")
    assert_not_empty ceo.description, "CEO description should not be blank"
    assert_not_empty ceo.job_spec, "CEO job_spec should not be blank"
    assert_includes ceo.description, "Chief Executive Officer"
  end

  test "finds existing CEO instead of creating duplicate" do
    company = companies(:acme) # acme already has a CEO role
    RoleTemplates::BulkApplicator.call(company: company)

    assert_equal 1, company.roles.where(title: "CEO").count,
      "Should not create a duplicate CEO -- must find and reuse the existing one"
  end

  test "CEO skipped count is 1 when CEO already exists" do
    company = companies(:acme)
    result = RoleTemplates::BulkApplicator.call(company: company)

    assert result.skipped >= 1,
      "Expected at least 1 skipped role (the existing CEO)"
  end

  # --- Idempotency (APPLY-05 + APPLY-02) ---

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
    assert_equal 1 + expected_template_roles, result.created
  end

  test "result aggregates skipped count from all templates" do
    company = companies(:widgets)
    RoleTemplates::BulkApplicator.call(company: company)

    result = RoleTemplates::BulkApplicator.call(company: company)

    expected_total = 1 + RoleTemplates::Registry.all.sum { |t| t.roles.size }
    assert_equal expected_total, result.skipped
  end

  test "result success? is true when all templates succeed" do
    company = companies(:widgets)
    result = RoleTemplates::BulkApplicator.call(company: company)

    assert result.success?
  end

  test "result summary describes total created and skipped" do
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

  # --- Partial overlap ---

  test "skips pre-existing roles while creating new ones" do
    # acme has CEO and CTO -- both should be skipped
    company = companies(:acme)
    result = RoleTemplates::BulkApplicator.call(company: company)

    # CEO and CTO are both pre-existing -> skipped count must be at least 2
    assert result.skipped >= 2,
      "Expected at least 2 skipped (CEO + CTO), got #{result.skipped}"

    # Other engineering roles (VP Engineering, Tech Lead, Engineer, QA) should be created
    assert company.roles.exists?(title: "VP Engineering")
    assert company.roles.exists?(title: "Tech Lead")
    assert company.roles.exists?(title: "Engineer")
    assert company.roles.exists?(title: "QA")
  end

  test "children of skipped CTO still get correct parent in acme" do
    company = companies(:acme)
    RoleTemplates::BulkApplicator.call(company: company)

    existing_cto = company.roles.find_by!(title: "CTO")
    vp = company.roles.find_by!(title: "VP Engineering")

    assert_equal existing_cto, vp.parent,
      "VP Engineering should be parented to the pre-existing acme CTO"
  end
end
