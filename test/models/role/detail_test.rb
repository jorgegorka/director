require "test_helper"

class Role::DetailTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @role = roles(:cto)
    @detail = Role::Detail.new(@role, @project)
  end

  test "recent_heartbeats returns heartbeat events in reverse chronological order" do
    heartbeats = @detail.recent_heartbeats
    assert_kind_of ActiveRecord::Relation, heartbeats
    assert heartbeats.size <= 5
    assert heartbeats.all? { |h| h.role_id == @role.id }
  end

  test "recent_heartbeats is memoized" do
    assert_same @detail.recent_heartbeats, @detail.recent_heartbeats
  end

  test "recent_runs returns role runs ordered by most recent" do
    runs = @detail.recent_runs
    assert_kind_of ActiveRecord::Relation, runs
    assert runs.size <= 5
    assert runs.all? { |r| r.role_id == @role.id }
  end

  test "recent_runs is memoized" do
    assert_same @detail.recent_runs, @detail.recent_runs
  end

  test "project_skills returns skills ordered by category and name" do
    skills = @detail.project_skills
    assert_kind_of ActiveRecord::Relation, skills
    assert skills.all? { |s| s.project_id == @project.id }
    categories = skills.map(&:category)
    assert_equal categories, categories.sort
  end

  test "project_skills is memoized" do
    assert_same @detail.project_skills, @detail.project_skills
  end

  test "role_skills_by_skill_id returns hash indexed by skill_id" do
    mapping = @detail.role_skills_by_skill_id
    assert_kind_of Hash, mapping
    mapping.each do |skill_id, role_skill|
      assert_equal skill_id, role_skill.skill_id
      assert_equal @role.id, role_skill.role_id
    end
  end

  test "role_skills_by_skill_id is memoized" do
    assert_same @detail.role_skills_by_skill_id, @detail.role_skills_by_skill_id
  end

  test "role_goals returns goals for the role" do
    goals = @detail.role_goals
    assert goals.all? { |g| g.role_id == @role.id }
  end

  test "role_goals is memoized" do
    assert_same @detail.role_goals, @detail.role_goals
  end

  test "eval_total returns count of goal evaluations" do
    expected = @role.goal_evaluations.count
    assert_equal expected, @detail.eval_total
  end

  test "eval_total is memoized" do
    first_call = @detail.eval_total
    assert_equal first_call, @detail.eval_total
  end

  test "eval_pass_count returns count of passed evaluations" do
    expected = @role.goal_evaluations.passed.count
    assert_equal expected, @detail.eval_pass_count
  end

  test "eval_pass_count is memoized" do
    first_call = @detail.eval_pass_count
    assert_equal first_call, @detail.eval_pass_count
  end

  test "recent_evaluations returns evaluations with task and goal eager loaded" do
    evaluations = @detail.recent_evaluations
    assert evaluations.size <= 5
    assert evaluations.all? { |e| e.role_id == @role.id }
    evaluations.each do |evaluation|
      assert evaluation.association(:task).loaded?
      assert evaluation.association(:goal).loaded?
    end
  end

  test "recent_evaluations is memoized" do
    assert_same @detail.recent_evaluations, @detail.recent_evaluations
  end

  test "any_evaluations? returns true when evaluations exist" do
    assert @detail.eval_total > 0
    assert @detail.any_evaluations?
  end

  test "any_evaluations? returns false when no evaluations" do
    role = roles(:developer)
    detail = Role::Detail.new(role, @project)
    assert_not detail.any_evaluations?
  end

  test "eval_pass_rate returns percentage of passed evaluations" do
    rate = @detail.eval_pass_rate
    assert_kind_of Integer, rate
    assert rate >= 0
    assert rate <= 100

    expected = ((@detail.eval_pass_count.to_f / @detail.eval_total) * 100).round
    assert_equal expected, rate
  end

  test "eval_pass_rate returns 0 when no evaluations" do
    role = roles(:developer)
    detail = Role::Detail.new(role, @project)
    assert_equal 0, detail.eval_pass_rate
  end

  test "exposes role and project via attr_reader" do
    assert_equal @role, @detail.role
    assert_equal @project, @detail.project
  end
end
