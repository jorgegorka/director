require "test_helper"

class Roles::PromptBuilderTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @task = tasks(:design_homepage)
    @context = {
      task_id: @task.id,
      task_title: @task.title,
      task_description: @task.description
    }
  end

  # --- compose_system_prompt ---

  test "system prompt includes identity section" do
    prompt = @role.compose_system_prompt({})

    assert_includes prompt, "## Your Identity"
    assert_includes prompt, @role.title
    assert_includes prompt, @role.project.name
  end

  test "system prompt includes role job_spec when present" do
    @role.job_spec = "You are the CTO."
    prompt = @role.compose_system_prompt({})

    assert_includes prompt, "You are the CTO."
  end

  test "system prompt includes category job_spec" do
    prompt = @role.compose_system_prompt({})

    assert_includes prompt, @role.role_category.job_spec
  end

  test "system prompt orders: identity, job_spec, category_spec, mission, skills" do
    @role.job_spec = "You are the CTO."
    context = {
      root_task_title: "Improve SEO",
      skills: [
        { key: "seo", name: "SEO", description: "Optimize search", category: "marketing", markdown: "# SEO" }
      ]
    }

    prompt = @role.compose_system_prompt(context)

    identity_pos = prompt.index("Your Identity")
    job_spec_pos = prompt.index("You are the CTO.")
    category_pos = prompt.index(@role.role_category.job_spec)
    mission_pos = prompt.index("Mission Context")
    skills_pos = prompt.index("Your Skills")

    assert identity_pos < job_spec_pos, "Identity should appear before job spec"
    assert job_spec_pos < category_pos, "Job spec should appear before category spec"
    assert category_pos < mission_pos, "Category spec should appear before mission"
    assert mission_pos < skills_pos, "Mission should appear before skills"
  end

  test "system prompt omits category job_spec when role has no category" do
    role_without_category = @role.dup
    role_without_category.define_singleton_method(:role_category) { nil }

    prompt = role_without_category.compose_system_prompt({})

    assert_includes prompt, "Your Identity"
  end

  test "system prompt includes mission section when root task present" do
    context = {
      root_task_title: "Improve SEO rankings",
      root_task_description: "Increase organic traffic by 30%"
    }

    prompt = @role.compose_system_prompt(context)

    assert_includes prompt, "## Mission Context"
    assert_includes prompt, "**Improve SEO rankings**"
    assert_includes prompt, "Increase organic traffic by 30%"
    assert_includes prompt, "## Focus Rules"
  end

  test "system prompt omits mission section when no root task" do
    prompt = @role.compose_system_prompt({})

    assert_not_includes prompt, "Mission Context"
  end

  test "system prompt includes skills catalog when skills present" do
    skills = [
      { key: "code_review", name: "Code Review", description: "Review code", category: "technical", markdown: "# Code Review\n\n## Instructions\n1. Review the code" }
    ]

    prompt = @role.compose_system_prompt({ skills: skills })

    assert_includes prompt, "## Your Skills"
    assert_includes prompt, "Code Review"
    assert_includes prompt, "code_review"
  end

  test "system prompt omits skills section when no skills" do
    prompt = @role.compose_system_prompt({ skills: [] })

    assert_not_includes prompt, "Your Skills"
  end

  test "skills catalog includes linked document hints" do
    skills = [
      {
        key: "blog_writing", name: "Blog Writing", description: "Write blog posts",
        category: "creative", markdown: "# Blog Writing",
        linked_documents: [ { id: 1, title: "Company Mission" }, { id: 2, title: "Brand Guide" } ]
      }
    ]

    prompt = @role.compose_system_prompt({ skills: skills })

    assert_includes prompt, 'Related docs: "Company Mission", "Brand Guide"'
  end

  test "identity prompt includes organization hierarchy" do
    prompt = roles(:ceo).compose_system_prompt({})

    assert_includes prompt, "## Your Organization"
    assert_includes prompt, "CTO"
  end

  test "identity prompt does not include behavioral instructions" do
    prompt = @role.compose_system_prompt({})

    identity_end = prompt.index(@role.role_category.job_spec)
    identity_section = prompt[0...identity_end]

    assert_not_includes identity_section, "Efficiency Rules"
    assert_not_includes identity_section, "How to Work"
  end

  # --- build_user_prompt ---

  test "user prompt for task assignment includes task details" do
    prompt = @role.build_user_prompt(@context)

    assert_includes prompt, "Task ##{@task.id}"
    assert_includes prompt, @task.title
    assert_includes prompt, "start working immediately"
  end

  test "user prompt for review includes review cue" do
    context = {
      trigger_type: "task_pending_review",
      task_id: @task.id,
      task_title: @task.title,
      assignee_role_title: "Marketing Planner"
    }

    prompt = @role.build_user_prompt(context)

    assert_includes prompt, "pending your review"
    assert_includes prompt, "Marketing Planner"
    assert_not_includes prompt, "assigned"
  end

  test "user prompt fallback when no task context" do
    prompt = @role.build_user_prompt({})

    assert_includes prompt, "list_my_tasks"
  end

  test "user prompt includes task documents when present" do
    context = {
      task_id: 42,
      task_title: "Write blog post",
      task_description: "Write about our project",
      task_documents: [
        { id: 1, title: "Company Mission", body: "We build great things." }
      ]
    }

    prompt = @role.build_user_prompt(context)

    assert_includes prompt, "## Reference Documents"
    assert_includes prompt, '<document title="Company Mission">'
    assert_includes prompt, "We build great things."
  end

  test "user prompt includes active subtasks for root tasks" do
    context = {
      task_id: 1,
      task_title: "Improve SEO",
      task_description: "Increase traffic",
      active_subtasks: [
        { id: 10, title: "Audit sitemap", status: "in_progress" },
        { id: 11, title: "Fix meta tags", status: "open" }
      ]
    }

    prompt = @role.build_user_prompt(context)

    assert_includes prompt, "Task #10: Audit sitemap (in_progress)"
    assert_includes prompt, "Task #11: Fix meta tags (open)"
    assert_includes prompt, "do NOT create new subtasks"
  end

  # --- compose_unified_prompt ---

  test "unified prompt combines system and user prompts" do
    context = {
      task_id: @task.id,
      task_title: @task.title,
      task_description: @task.description
    }

    prompt = @role.compose_unified_prompt(context)

    assert_includes prompt, "## Your Identity"
    assert_includes prompt, @role.role_category.job_spec
    assert_includes prompt, "---"
    assert_includes prompt, "Task ##{@task.id}"
  end
end
