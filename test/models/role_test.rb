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

  test "destroying parent nullifies children parent_id" do
    @cto.destroy
    @developer.reload
    assert_nil @developer.parent_id
  end

  test "destroying company destroys all roles" do
    role_count = @company.roles.count
    assert role_count > 0
    assert_difference("Role.count", -role_count) do
      @company.destroy
    end
  end
end
