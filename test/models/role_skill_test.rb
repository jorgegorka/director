require "test_helper"

class RoleSkillTest < ActiveSupport::TestCase
  setup do
    @cto = roles(:cto)
    @developer = roles(:developer)
    @widgets_lead = roles(:widgets_lead)
    @acme_skill = skills(:acme_code_review)
    @widgets_skill = skills(:widgets_strategic_planning)
  end

  # --- Validations ---

  test "valid with role and skill from same company" do
    role_skill = RoleSkill.new(role: @cto, skill: skills(:acme_data_analysis))
    assert role_skill.valid?
  end

  test "invalid with duplicate skill on same role" do
    role_skill = RoleSkill.new(role: @cto, skill: @acme_skill)
    assert_not role_skill.valid?
    assert role_skill.errors[:skill_id].any?
  end

  test "allows same skill on different roles" do
    role_skill = RoleSkill.new(role: @developer, skill: @acme_skill)
    assert role_skill.valid?
  end

  test "invalid when role and skill from different companies" do
    role_skill = RoleSkill.new(role: @cto, skill: @widgets_skill)
    assert_not role_skill.valid?
    assert_includes role_skill.errors[:skill], "must belong to the same company as the role"
  end

  test "invalid when widget role assigned acme skill" do
    role_skill = RoleSkill.new(role: @widgets_lead, skill: @acme_skill)
    assert_not role_skill.valid?
  end

  # --- Associations ---

  test "belongs to role" do
    assert_equal @cto, role_skills(:cto_code_review).role
  end

  test "belongs to skill" do
    assert_equal @acme_skill, role_skills(:cto_code_review).skill
  end
end
