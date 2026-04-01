require "test_helper"

class Tools::HireRoleTest < ActiveSupport::TestCase
  setup do
    @cmo = roles(:cmo)
    @cmo.update!(auto_hire_enabled: true)
  end

  test "hires subordinate role from template" do
    tool = Tools::HireRole.new(@cmo)
    hirable = @cmo.hirable_roles.first

    result = tool.call({ "template_role_title" => hirable.title, "budget_cents" => 10000 })

    assert_equal "hired", result[:status]
    assert result[:role_id].present?
    assert_equal hirable.title, result[:title]
  end

  test "hired role is a child of the hiring role" do
    tool = Tools::HireRole.new(@cmo)
    hirable = @cmo.hirable_roles.first

    result = tool.call({ "template_role_title" => hirable.title, "budget_cents" => 10000 })

    new_role = Role.find(result[:role_id])
    assert_equal @cmo.id, new_role.parent_id
  end

  test "creates pending hire when auto_hire disabled" do
    @cmo.update!(auto_hire_enabled: false)
    tool = Tools::HireRole.new(@cmo)
    hirable = @cmo.hirable_roles.first

    result = tool.call({ "template_role_title" => hirable.title, "budget_cents" => 10000 })

    assert_equal "pending_approval", result[:status]
    assert result[:pending_hire_id].present?
  end

  test "raises ArgumentError for invalid role title" do
    tool = Tools::HireRole.new(@cmo)

    assert_raises(ArgumentError) do
      tool.call({ "template_role_title" => "Nonexistent Role", "budget_cents" => 10000 })
    end
  end
end
