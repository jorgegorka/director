require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "valid with name" do
    company = Company.new(name: "Test Corp")
    assert company.valid?
  end

  test "invalid without name" do
    company = Company.new(name: nil)
    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end

  test "has many memberships" do
    company = companies(:acme)
    assert_equal 2, company.memberships.count
  end

  test "has many users through memberships" do
    company = companies(:acme)
    assert_includes company.users, users(:one)
    assert_includes company.users, users(:two)
  end

  test "destroying company destroys memberships" do
    company = companies(:acme)
    assert_difference("Membership.count", -2) do
      company.destroy
    end
  end

  # --- Skill Seeding ---

  test "seed_default_skills! creates builtin skills from YAML files" do
    company = Company.create!(name: "Fresh Corp")
    # after_create fires seed_default_skills! automatically
    skill_count = Dir[Rails.root.join("db/seeds/skills/*.yml")].size
    assert_equal skill_count, company.skills.builtin.count,
      "Expected #{skill_count} builtin skills, got #{company.skills.builtin.count}"
  end

  test "seed_default_skills! sets correct attributes from YAML" do
    company = Company.create!(name: "Attr Check Corp")
    skill = company.skills.find_by(key: "code_review")
    assert_not_nil skill, "code_review skill should exist"
    assert_equal "Code Review", skill.name
    assert_equal "technical", skill.category
    assert skill.builtin?, "Should be builtin"
    assert skill.markdown.length >= 200, "Markdown should have meaningful content"
  end

  test "seed_default_skills! is idempotent" do
    company = Company.create!(name: "Idempotent Corp")
    initial_count = company.skills.count
    company.seed_default_skills!
    assert_equal initial_count, company.skills.count,
      "Running seed_default_skills! again should not create duplicates"
  end

  test "seed_default_skills! does not overwrite existing skills" do
    company = Company.create!(name: "Preserve Corp")
    skill = company.skills.find_by(key: "code_review")
    skill.update!(markdown: "Custom instructions")
    company.seed_default_skills!
    skill.reload
    assert_equal "Custom instructions", skill.markdown,
      "Existing skill markdown should not be overwritten"
  end

  test "seed_default_skills! fills in missing skills for company with partial set" do
    company = Company.create!(name: "Partial Corp")
    total = company.skills.count
    # Delete some skills
    company.skills.where(category: "leadership").destroy_all
    deleted_count = total - company.skills.count
    assert deleted_count > 0, "Should have deleted some skills"
    # Re-seed
    company.seed_default_skills!
    assert_equal total, company.skills.count,
      "Should restore deleted skills"
  end

  test "after_create seeds skills for new company" do
    skill_count = Dir[Rails.root.join("db/seeds/skills/*.yml")].size
    company = nil
    assert_difference("Skill.count", skill_count) do
      company = Company.create!(name: "Auto Seed Corp")
    end
    assert company.skills.any?, "New company should have skills after creation"
  end
end
