require "test_helper"

class Roles::HiringTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @ceo = roles(:ceo)
    @cto = roles(:cto)
  end

  # --- department_template ---

  test "CTO resolves to engineering department template" do
    template = @cto.department_template
    assert_not_nil template
    assert_equal "engineering", template.key
  end

  test "CEO has no department template (it is the company root)" do
    assert_nil @ceo.department_template
  end

  test "developer resolves to engineering department template via parent chain" do
    developer = roles(:developer)
    template = developer.department_template
    assert_not_nil template
    assert_equal "engineering", template.key
  end

  # --- hirable_roles ---

  test "CTO can hire roles from engineering template below its level" do
    hirable = @cto.hirable_roles
    hirable_titles = hirable.map(&:title)

    assert_includes hirable_titles, "VP Engineering"
    assert_includes hirable_titles, "Tech Lead"
    assert_includes hirable_titles, "Engineer"
    assert_includes hirable_titles, "QA"
    assert_not_includes hirable_titles, "CTO"
  end

  test "hirable_roles excludes roles that already exist in the company" do
    hirable = @cto.hirable_roles
    hirable_titles = hirable.map(&:title)

    assert hirable_titles.size > 0
  end

  test "CEO returns empty hirable_roles (no department template)" do
    assert_empty @ceo.hirable_roles
  end

  # --- can_hire? ---

  test "CTO can hire VP Engineering" do
    assert @cto.can_hire?("VP Engineering")
  end

  test "CTO cannot hire CTO (same level)" do
    assert_not @cto.can_hire?("CTO")
  end

  test "CTO cannot hire nonexistent role" do
    assert_not @cto.can_hire?("Janitor")
  end

  # --- hire! with auto_hire_enabled ---

  test "hire! creates subordinate role when auto_hire_enabled" do
    @cto.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      new_role = @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)

      assert_equal "VP Engineering", new_role.title
      assert_equal @cto, new_role.parent
      assert_equal @cto.adapter_type, new_role.adapter_type
      assert_equal @cto.adapter_config, new_role.adapter_config
      assert_equal 20000, new_role.budget_cents
      assert_equal @company, new_role.company
      assert new_role.idle?
    end
  end

  test "hire! records audit event when auto_hire_enabled" do
    @cto.update!(auto_hire_enabled: true)

    assert_difference "AuditEvent.count", 1 do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end

    event = AuditEvent.last
    assert_equal "role_hired", event.action
    assert_equal "VP Engineering", event.metadata["hired_role_title"]
  end

  test "hire! raises when budget_cents exceeds own budget" do
    @cto.update!(auto_hire_enabled: true)

    error = assert_raises(Roles::Hiring::HiringError) do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 999_999)
    end
    assert_match(/budget/i, error.message)
  end

  test "hire! raises for non-hirable role title" do
    @cto.update!(auto_hire_enabled: true)

    error = assert_raises(Roles::Hiring::HiringError) do
      @cto.hire!(template_role_title: "CEO", budget_cents: 10000)
    end
    assert_match(/cannot hire/i, error.message)
  end

  test "hire! raises when role already exists in company" do
    @cto.update!(auto_hire_enabled: true)
    @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)

    error = assert_raises(Roles::Hiring::HiringError) do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end
    assert_match(/already exists/i, error.message)
  end

  # --- hire! without auto_hire_enabled (pending approval) ---

  test "hire! creates pending hire and blocks agent when auto_hire disabled" do
    assert_not @cto.auto_hire_enabled?

    assert_difference "PendingHire.count", 1 do
      result = @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
      assert_kind_of PendingHire, result
      assert result.pending?
    end

    @cto.reload
    assert @cto.pending_approval?
  end

  test "hire! notifies admins when pending approval" do
    assert_difference "Notification.count" do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end

    notification = Notification.last
    assert_equal "hire_approval_requested", notification.action
    assert_equal "VP Engineering", notification.metadata["requested_hire"]
  end

  test "hire! records audit event when pending approval" do
    assert_difference "AuditEvent.count", 1 do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end

    event = AuditEvent.last
    assert_equal "hire_requested", event.action
  end

  # --- execute_hire! (called after approval) ---

  test "execute_hire! creates the role from pending hire data" do
    pending_hire = PendingHire.create!(
      role: @cto,
      company: @company,
      template_role_title: "VP Engineering",
      budget_cents: 20000
    )

    assert_difference "Role.count", 1 do
      new_role = @cto.execute_hire!(pending_hire)
      assert_equal "VP Engineering", new_role.title
      assert_equal @cto, new_role.parent
    end
  end
end
