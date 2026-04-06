require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "valid with name" do
    project = Project.new(name: "Test Corp")
    assert project.valid?
  end

  test "invalid without name" do
    project = Project.new(name: nil)
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "has many memberships" do
    project = projects(:acme)
    assert_equal 2, project.memberships.count
  end

  test "has many users through memberships" do
    project = projects(:acme)
    assert_includes project.users, users(:one)
    assert_includes project.users, users(:two)
  end

  test "destroying project destroys memberships" do
    project = projects(:acme)
    assert_difference("Membership.count", -2) do
      project.destroy
    end
  end

  # --- Skill Seeding ---

  test "seed_default_skills! creates builtin skills from YAML files" do
    project = Project.create!(name: "Fresh Corp")
    # after_create fires seed_default_skills! automatically
    skill_count = Dir[Rails.root.join("db/seeds/skills/*.yml")].size
    assert_equal skill_count, project.skills.builtin.count,
      "Expected #{skill_count} builtin skills, got #{project.skills.builtin.count}"
  end

  test "seed_default_skills! sets correct attributes from YAML" do
    project = Project.create!(name: "Attr Check Corp")
    skill = project.skills.find_by(key: "code_review")
    assert_not_nil skill, "code_review skill should exist"
    assert_equal "Code Review", skill.name
    assert_equal "technical", skill.category
    assert skill.builtin?, "Should be builtin"
    assert skill.markdown.length >= 200, "Markdown should have meaningful content"
  end

  test "seed_default_skills! is idempotent" do
    project = Project.create!(name: "Idempotent Corp")
    initial_count = project.skills.count
    project.seed_default_skills!
    assert_equal initial_count, project.skills.count,
      "Running seed_default_skills! again should not create duplicates"
  end

  test "seed_default_skills! does not overwrite existing skills" do
    project = Project.create!(name: "Preserve Corp")
    skill = project.skills.find_by(key: "code_review")
    skill.update!(markdown: "Custom instructions")
    project.seed_default_skills!
    skill.reload
    assert_equal "Custom instructions", skill.markdown,
      "Existing skill markdown should not be overwritten"
  end

  test "seed_default_skills! fills in missing skills for project with partial set" do
    project = Project.create!(name: "Partial Corp")
    total = project.skills.count
    # Delete some skills
    project.skills.where(category: "leadership").destroy_all
    deleted_count = total - project.skills.count
    assert deleted_count > 0, "Should have deleted some skills"
    # Re-seed
    project.seed_default_skills!
    assert_equal total, project.skills.count,
      "Should restore deleted skills"
  end

  test "after_create seeds skills for new project" do
    skill_count = Dir[Rails.root.join("db/seeds/skills/*.yml")].size
    project = nil
    assert_difference("Skill.count", skill_count) do
      project = Project.create!(name: "Auto Seed Corp")
    end
    assert project.skills.any?, "New project should have skills after creation"
  end

  # --- Validation: max_concurrent_agents ---

  test "valid with max_concurrent_agents zero" do
    project = Project.new(name: "Test", max_concurrent_agents: 0)
    assert project.valid?
  end

  test "invalid with negative max_concurrent_agents" do
    project = Project.new(name: "Test", max_concurrent_agents: -1)
    assert_not project.valid?
    assert project.errors[:max_concurrent_agents].any?
  end

  test "invalid with non-integer max_concurrent_agents" do
    project = Project.new(name: "Test", max_concurrent_agents: 1.5)
    assert_not project.valid?
  end

  # --- Concurrency Limits ---

  test "concurrent_agent_limit_reached? returns false when limit is zero" do
    project = projects(:acme)
    project.update!(max_concurrent_agents: 0)
    assert_not project.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? returns false when under limit" do
    project = projects(:acme)
    project.update!(max_concurrent_agents: 10)
    assert_not project.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? returns true when at limit" do
    project = projects(:acme)
    project.update!(max_concurrent_agents: 1)
    role = project.roles.first
    role.role_runs.create!(project: project, status: :running, trigger_type: "scheduled")
    assert project.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? counts queued and running runs" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 2)
    role = project.roles.first
    role.role_runs.create!(project: project, status: :queued, trigger_type: "scheduled")
    role.role_runs.create!(project: project, status: :running, trigger_type: "scheduled")
    assert project.concurrent_agent_limit_reached?
  end

  test "concurrent_agent_limit_reached? does not count throttled runs" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 2)
    role = project.roles.first
    role.role_runs.create!(project: project, status: :running, trigger_type: "scheduled")
    role.role_runs.create!(project: project, status: :throttled, trigger_type: "scheduled")
    assert_not project.concurrent_agent_limit_reached?
  end

  # --- Drain Throttled Runs ---

  test "dispatch_next_throttled_run! dispatches oldest throttled run" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 1)
    role = project.roles.first

    older = role.role_runs.create!(project: project, status: :throttled, trigger_type: "scheduled", created_at: 2.minutes.ago)
    _newer = role.role_runs.create!(project: project, status: :throttled, trigger_type: "scheduled", created_at: 1.minute.ago)

    project.dispatch_next_throttled_run!
    older.reload

    assert older.queued?, "Oldest throttled run should be queued, got #{older.status}"
  end

  test "dispatch_next_throttled_run! does nothing when at capacity" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 1)
    role = project.roles.first

    role.role_runs.create!(project: project, status: :running, trigger_type: "scheduled")
    throttled = role.role_runs.create!(project: project, status: :throttled, trigger_type: "scheduled")

    project.dispatch_next_throttled_run!
    assert throttled.reload.throttled?, "Throttled run should remain throttled"
  end

  test "dispatch_next_throttled_run! does nothing when no throttled runs" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 1)

    assert_nothing_raised { project.dispatch_next_throttled_run! }
  end

  test "dispatch_next_throttled_run! skips roles with active runs" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 5)

    busy_role = roles(:cto)
    idle_role = roles(:developer)

    busy_role.role_runs.create!(project: project, status: :running, trigger_type: "scheduled")
    busy_throttled = busy_role.role_runs.create!(project: project, status: :throttled, trigger_type: "task_assigned", created_at: 2.minutes.ago)
    idle_throttled = idle_role.role_runs.create!(project: project, status: :throttled, trigger_type: "task_assigned", created_at: 1.minute.ago)

    project.dispatch_next_throttled_run!

    assert idle_throttled.reload.queued?, "Idle role's throttled run should be dispatched"
    assert busy_throttled.reload.throttled?, "Busy role's throttled run should remain throttled"
  end

  test "dispatch_next_throttled_run! does nothing when all throttled roles are busy" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 5)

    role = roles(:cto)
    role.role_runs.create!(project: project, status: :running, trigger_type: "scheduled")
    throttled = role.role_runs.create!(project: project, status: :throttled, trigger_type: "task_assigned")

    assert_no_enqueued_jobs(only: ExecuteRoleJob) do
      project.dispatch_next_throttled_run!
    end

    assert throttled.reload.throttled?, "Throttled run should remain throttled"
  end

  test "dispatch_next_throttled_run! enqueues ExecuteRoleJob" do
    project = projects(:acme)
    RoleRun.where(project: project).delete_all
    project.update!(max_concurrent_agents: 1)
    role = project.roles.first

    throttled = role.role_runs.create!(project: project, status: :throttled, trigger_type: "scheduled")

    assert_enqueued_with(job: ExecuteRoleJob, args: [ throttled.id ]) do
      project.dispatch_next_throttled_run!
    end
  end
end
