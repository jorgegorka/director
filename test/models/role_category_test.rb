require "test_helper"

class RoleCategoryTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @orchestrator = role_categories(:orchestrator)
    Current.company = @company
  end

  teardown do
    Current.company = nil
  end

  # --- Validations ---

  test "valid with name, job_spec, and company" do
    category = RoleCategory.new(name: "Custom", job_spec: "Do custom work.", company: @company)
    assert category.valid?
  end

  test "requires name" do
    category = RoleCategory.new(job_spec: "Do work.", company: @company)
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "requires job_spec" do
    category = RoleCategory.new(name: "Custom", company: @company)
    assert_not category.valid?
    assert_includes category.errors[:job_spec], "can't be blank"
  end

  test "name must be unique within company" do
    duplicate = RoleCategory.new(name: "Orchestrator", job_spec: "Duplicate.", company: @company)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "already exists in this company"
  end

  test "same name allowed in different companies" do
    widgets = companies(:widgets)
    category = RoleCategory.new(name: "Planner", job_spec: "Plan things.", company: widgets)
    assert category.valid?
  end

  # --- Associations ---

  test "has many roles" do
    assert_respond_to @orchestrator, :roles
    assert @orchestrator.roles.count > 0
  end

  test "cannot delete category with assigned roles" do
    assert_not @orchestrator.destroy
    assert_includes @orchestrator.errors[:base].join, "Cannot delete record"
  end

  test "can delete category with no roles" do
    category = RoleCategory.create!(name: "Temporary", job_spec: "Temp.", company: @company)
    assert category.destroy
  end

  # --- Tenantable ---

  test "scoped to current company" do
    scoped = RoleCategory.for_current_company
    assert_includes scoped.map(&:company_id).uniq, @company.id
    assert_not_includes scoped.map(&:company_id).uniq, companies(:widgets).id
  end

  # --- Default definitions ---

  test "default_definitions returns array of category hashes" do
    defs = RoleCategory.default_definitions
    assert_kind_of Array, defs
    assert defs.size >= 3
    assert defs.all? { |d| d.key?("name") && d.key?("job_spec") }
  end

  test "default definitions include Orchestrator, Planner, Worker" do
    names = RoleCategory.default_definitions.map { |d| d["name"] }
    assert_includes names, "Orchestrator"
    assert_includes names, "Planner"
    assert_includes names, "Worker"
  end
end
