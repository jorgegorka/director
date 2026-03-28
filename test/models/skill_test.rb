require "test_helper"

class SkillTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @widgets = companies(:widgets)
    @skill = skills(:acme_code_review)
  end

  # --- Validations ---

  test "valid with key, name, markdown, and company" do
    skill = Skill.new(
      company: @company,
      key: "new_skill",
      name: "New Skill",
      markdown: "# New Skill\n\nContent here."
    )
    assert skill.valid?
  end

  test "invalid without key" do
    skill = Skill.new(company: @company, key: nil, name: "Test", markdown: "# Test")
    assert_not skill.valid?
    assert_includes skill.errors[:key], "can't be blank"
  end

  test "invalid without name" do
    skill = Skill.new(company: @company, key: "test_key", name: nil, markdown: "# Test")
    assert_not skill.valid?
    assert_includes skill.errors[:name], "can't be blank"
  end

  test "invalid without markdown" do
    skill = Skill.new(company: @company, key: "test_key", name: "Test", markdown: nil)
    assert_not skill.valid?
    assert_includes skill.errors[:markdown], "can't be blank"
  end

  test "invalid with duplicate key in same company" do
    skill = Skill.new(company: @company, key: "code_review", name: "Code Review 2", markdown: "# Duplicate")
    assert_not skill.valid?
    assert skill.errors[:key].any?
  end

  test "allows duplicate key across different companies" do
    skill = Skill.new(company: @widgets, key: "code_review", name: "Code Review", markdown: "# Code Review")
    assert skill.valid?
  end

  test "builtin defaults to true" do
    skill = Skill.new
    assert_equal true, skill.builtin
  end

  # --- Associations ---

  test "belongs to company via Tenantable" do
    assert_equal @company, @skill.company
  end

  test "has many agent_skills" do
    assert @skill.respond_to?(:agent_skills)
  end

  test "has many agents through agent_skills" do
    assert_includes skills(:acme_code_review).agents, agents(:claude_agent)
  end

  # --- Scopes ---

  test "for_current_company scopes to Current.company" do
    Current.company = @company
    acme_skills = Skill.for_current_company
    assert_includes acme_skills, skills(:acme_code_review)
    assert_not_includes acme_skills, skills(:widgets_strategic_planning)
  end

  test "by_category filters by category" do
    technical_skills = Skill.by_category("technical")
    assert_includes technical_skills, skills(:acme_code_review)
    assert_not_includes technical_skills, skills(:acme_strategic_planning)
  end

  test "builtin scope returns only builtin skills" do
    builtin_skills = Skill.builtin
    assert_includes builtin_skills, skills(:acme_code_review)
    assert_not_includes builtin_skills, skills(:acme_custom_skill)
  end

  test "custom scope returns only non-builtin skills" do
    custom_skills = Skill.custom
    assert_includes custom_skills, skills(:acme_custom_skill)
    assert_not_includes custom_skills, skills(:acme_code_review)
  end
end
