require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  # --- Validation: max_concurrent_agents ---

  test "valid with max_concurrent_agents zero" do
    company = Company.new(name: "Test", max_concurrent_agents: 0)
    assert company.valid?
  end

  test "invalid with negative max_concurrent_agents" do
    company = Company.new(name: "Test", max_concurrent_agents: -1)
    assert_not company.valid?
    assert company.errors[:max_concurrent_agents].any?
  end

  test "invalid with non-integer max_concurrent_agents" do
    company = Company.new(name: "Test", max_concurrent_agents: 1.5)
    assert_not company.valid?
  end

  # --- Concurrency Limits ---

  test "concurrent_agent_limit_reached? returns false when limit is zero" do
    company = companies(:acme)
    company.update!(max_concurrent_agents: 0)
    assert_not company.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? returns false when under limit" do
    company = companies(:acme)
    company.update!(max_concurrent_agents: 10)
    assert_not company.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? returns true when at limit" do
    company = companies(:acme)
    company.update!(max_concurrent_agents: 1)
    role = company.roles.first
    role.role_runs.create!(company: company, status: :running, trigger_type: "scheduled")
    assert company.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? counts queued and running runs" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 2)
    role = company.roles.first
    role.role_runs.create!(company: company, status: :queued, trigger_type: "scheduled")
    role.role_runs.create!(company: company, status: :running, trigger_type: "scheduled")
    assert company.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? does not count throttled runs" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 2)
    role = company.roles.first
    role.role_runs.create!(company: company, status: :running, trigger_type: "scheduled")
    role.role_runs.create!(company: company, status: :throttled, trigger_type: "scheduled")
    assert_not company.concurrent_agent_limit_reached?
  end

  # --- Drain Throttled Runs ---

  test "dispatch_next_throttled_run! dispatches oldest throttled run" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 1)
    role = company.roles.first

    older = role.role_runs.create!(company: company, status: :throttled, trigger_type: "scheduled", created_at: 2.minutes.ago)
    _newer = role.role_runs.create!(company: company, status: :throttled, trigger_type: "scheduled", created_at: 1.minute.ago)

    company.dispatch_next_throttled_run!
    older.reload

    assert older.queued?, "Oldest throttled run should be queued, got #{older.status}"
  end

  test "dispatch_next_throttled_run! does nothing when at capacity" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 1)
    role = company.roles.first

    role.role_runs.create!(company: company, status: :running, trigger_type: "scheduled")
    throttled = role.role_runs.create!(company: company, status: :throttled, trigger_type: "scheduled")

    company.dispatch_next_throttled_run!
    assert throttled.reload.throttled?, "Throttled run should remain throttled"
  end

  test "dispatch_next_throttled_run! does nothing when no throttled runs" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 1)

    assert_nothing_raised { company.dispatch_next_throttled_run! }
  end

  test "dispatch_next_throttled_run! skips roles with active runs" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 5)

    busy_role = roles(:cto)
    idle_role = roles(:developer)

    busy_role.role_runs.create!(company: company, status: :running, trigger_type: "scheduled")
    busy_throttled = busy_role.role_runs.create!(company: company, status: :throttled, trigger_type: "task_assigned", created_at: 2.minutes.ago)
    idle_throttled = idle_role.role_runs.create!(company: company, status: :throttled, trigger_type: "task_assigned", created_at: 1.minute.ago)

    company.dispatch_next_throttled_run!

    assert idle_throttled.reload.queued?, "Idle role's throttled run should be dispatched"
    assert busy_throttled.reload.throttled?, "Busy role's throttled run should remain throttled"
  end

  test "dispatch_next_throttled_run! does nothing when all throttled roles are busy" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 5)

    role = roles(:cto)
    role.role_runs.create!(company: company, status: :running, trigger_type: "scheduled")
    throttled = role.role_runs.create!(company: company, status: :throttled, trigger_type: "task_assigned")

    assert_no_enqueued_jobs(only: ExecuteRoleJob) do
      company.dispatch_next_throttled_run!
    end

    assert throttled.reload.throttled?, "Throttled run should remain throttled"
  end

  test "dispatch_next_throttled_run! enqueues ExecuteRoleJob" do
    company = companies(:acme)
    RoleRun.where(company: company).delete_all
    company.update!(max_concurrent_agents: 1)
    role = company.roles.first

    throttled = role.role_runs.create!(company: company, status: :throttled, trigger_type: "scheduled")

    assert_enqueued_with(job: ExecuteRoleJob, args: [ throttled.id ]) do
      company.dispatch_next_throttled_run!
    end
  end
end
