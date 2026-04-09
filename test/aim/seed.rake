class AIMSeed
  TAG = "[AIM]".freeze

  def run
    puts "#{TAG} Starting AIM seed..."
    find_or_create_user
    find_or_create_project
    clean_previous_aim_data
    seed_roles
    seed_goals_and_tasks
    verify
    puts "#{TAG} Done!"
  end

  private

    attr_reader :user, :project, :categories,
                :ceo, :vp_eng, :vp_strategy, :senior_dev, :qa_engineer, :research_analyst

    # ─── Setup ───────────────────────────────────────────────────────

    def find_or_create_user
      @user = User.find_by(email_address: "aim@director.test")
      unless @user
        @user = User.create!(email_address: "aim@director.test", password: "aim-test-password")
        puts "#{TAG}   Created user aim@director.test"
      end
      puts "#{TAG} User: #{@user.email_address}"
    end

    def find_or_create_project
      @project = Project.find_by(name: "AIM Test Project")
      unless @project
        @project = Project.create!(name: "AIM Test Project")
        Membership.create!(user: @user, project: @project, role: :owner)
        puts "#{TAG}   Created project"
      end
      Current.project = @project
      @categories = @project.role_categories.index_by(&:name)
      puts "#{TAG} Project: #{@project.name} (id: #{@project.id})"
      puts "#{TAG}   Categories: #{@categories.keys.join(', ')}"
    end

    # ─── Cleanup ─────────────────────────────────────────────────────

    def clean_previous_aim_data
      puts "#{TAG} Cleaning previous AIM data..."

      aim_role_ids = @project.roles.where("description LIKE ?", "%#{TAG}%").pluck(:id)

      if aim_role_ids.any?
        # Destroy all tasks that reference AIM roles (seeded + agent-created)
        all_aim_tasks = @project.tasks.where(
          "assignee_id IN (:ids) OR creator_id IN (:ids)", ids: aim_role_ids
        )
        all_aim_tasks.each(&:destroy)

        # Destroy AIM goals
        @project.goals.where("description LIKE ?", "%#{TAG}%").each(&:destroy)

        # Roles — destroy children first (hierarchy constraint).
        # Role#destroy handles remaining dependents (role_runs, role_skills, etc.)
        aim_roles = @project.roles.where(id: aim_role_ids)
        sorted = aim_roles.sort_by { |r| -r.ancestors.size }
        sorted.each(&:destroy)
      end

      puts "#{TAG}   Cleaned."
    end

    # ─── Roles ───────────────────────────────────────────────────────

    def seed_roles
      puts "#{TAG} Seeding roles..."

      adapter_config = { "model" => "claude-sonnet-4-20250514" }

      @ceo = create_role("AIM CEO", categories["Orchestrator"],
        description: "#{TAG} Root orchestrator. Delegates all work to VP Engineering and VP Strategy.",
        parent: nil, budget: 200_000, adapter_config: adapter_config)

      @vp_eng = create_role("AIM VP Engineering", categories["Orchestrator"],
        description: "#{TAG} Mid-level orchestrator. Manages Senior Dev and QA Engineer.",
        parent: @ceo, budget: 100_000, adapter_config: adapter_config)

      @vp_strategy = create_role("AIM VP Strategy", categories["Planner"],
        description: "#{TAG} Planner. Researches and produces plans. Can delegate data-gathering to Research Analyst.",
        parent: @ceo, budget: 50_000, adapter_config: adapter_config)

      @senior_dev = create_role("AIM Senior Dev", categories["Worker"],
        description: "#{TAG} Worker. Writes code and documentation directly.",
        parent: @vp_eng, budget: 50_000, adapter_config: adapter_config)

      @qa_engineer = create_role("AIM QA Engineer", categories["Worker"],
        description: "#{TAG} Worker. Tests and validates deliverables.",
        parent: @vp_eng, budget: 50_000, adapter_config: adapter_config)

      @research_analyst = create_role("AIM Research Analyst", categories["Worker"],
        description: "#{TAG} Worker. Gathers data and research for the planner.",
        parent: @vp_strategy, budget: 25_000, adapter_config: adapter_config)

      puts "#{TAG}   Roles seeded."
    end

    # ─── Goals & Tasks ───────────────────────────────────────────────

    def seed_goals_and_tasks
      puts "#{TAG} Seeding goals and tasks..."

      goal = Goal.create!(
        project: @project,
        title: "AIM: Build MVP Feature",
        description: "#{TAG} Build the minimum viable product feature set including auth, API, and tests.",
        role: @ceo,
        completion_percentage: 0
      )

      # Task 1: pending_review — for orchestrator review scenarios
      # Creator is vp_eng, assignee is senior_dev (subordinate of vp_eng — valid delegation)
      task_review = Task.create!(
        project: @project,
        title: "AIM: Write authentication module",
        description: "#{TAG} Implement user authentication with session management and password hashing.",
        creator: @vp_eng,
        assignee: @senior_dev,
        goal: goal,
        status: :pending_review,
        priority: :high
      )
      Message.create!(
        task: task_review,
        author: @senior_dev,
        body: "Implemented authentication with bcrypt password hashing, session tokens, and login/logout endpoints. All unit tests pass.",
        message_type: :comment
      )

      # Task 2: in_progress — for worker_does_work scenario
      Task.create!(
        project: @project,
        title: "AIM: Write API documentation",
        description: "#{TAG} Document the REST API endpoints including request/response formats and authentication.",
        creator: @vp_eng,
        assignee: @senior_dev,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 3: in_progress — for planner_direct_work scenario
      Task.create!(
        project: @project,
        title: "AIM: Analyze competitor pricing models",
        description: "#{TAG} Research 3 competitors and summarize their pricing models, tiers, and positioning.",
        creator: @ceo,
        assignee: @vp_strategy,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 4: in_progress — for worker_scope_discipline scenario
      Task.create!(
        project: @project,
        title: "AIM: Build entire platform from scratch",
        description: "#{TAG} Build authentication, billing, admin panel, API layer, frontend, deployment pipeline, monitoring, and documentation. This requires work across 8 different domains.",
        creator: @vp_eng,
        assignee: @senior_dev,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 5: in_progress — for worker_simple_task scenario
      Task.create!(
        project: @project,
        title: "AIM: Write test plan for authentication",
        description: "#{TAG} Write a test plan covering login, logout, session expiry, and password reset flows. List the test cases with expected results.",
        creator: @vp_eng,
        assignee: @qa_engineer,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 6: in_progress — for worker_flags_blocker scenario
      Task.create!(
        project: @project,
        title: "AIM: Integrate payment gateway",
        description: "#{TAG} Connect Stripe payment processing to the billing module. Requires API keys from the ops team which have not been provided yet.",
        creator: @vp_eng,
        assignee: @senior_dev,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 7: in_progress — for worker_stays_on_task scenario
      Task.create!(
        project: @project,
        title: "AIM: Compile list of enterprise AI platforms",
        description: "#{TAG} Research and list 10 enterprise AI orchestration platforms with their key features, pricing tier, and target market. Format as a table.",
        creator: @vp_strategy,
        assignee: @research_analyst,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 8: in_progress — for planner_delegates_research scenario
      Task.create!(
        project: @project,
        title: "AIM: Comprehensive market analysis",
        description: "#{TAG} Produce a full market analysis covering: competitor landscape (pricing, features, positioning), customer segments, market size estimates, regulatory environment, and technology trends. Each area requires deep research.",
        creator: @ceo,
        assignee: @vp_strategy,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 9: in_progress — for planner_simple_analysis scenario
      Task.create!(
        project: @project,
        title: "AIM: SWOT analysis of current product",
        description: "#{TAG} Produce a SWOT analysis (strengths, weaknesses, opportunities, threats) for our AI orchestration platform based on the current feature set and market position. One page maximum.",
        creator: @ceo,
        assignee: @vp_strategy,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 10: in_progress — for planner_mixed_complexity scenario
      Task.create!(
        project: @project,
        title: "AIM: Pricing strategy recommendation",
        description: "#{TAG} Write a pricing strategy recommendation. Part 1: summarize common SaaS pricing models and recommend which fits an AI orchestration platform (do this yourself). Part 2: gather customer willingness-to-pay data from 50 enterprise prospects (requires outreach and data collection — delegate this).",
        creator: @ceo,
        assignee: @vp_strategy,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 11: in_progress — for planner_submits_work scenario
      Task.create!(
        project: @project,
        title: "AIM: Write executive brief on AI market trends",
        description: "#{TAG} Write a one-page executive brief summarizing the top 3 AI market trends relevant to our product roadmap. This is for the CEO's weekly review.",
        creator: @ceo,
        assignee: @vp_strategy,
        goal: goal,
        status: :in_progress,
        priority: :medium
      )

      # Task 12: pending_review — for orch_no_self_review scenario
      task_strategy_review = Task.create!(
        project: @project,
        title: "AIM: Q2 strategic market assessment",
        description: "#{TAG} Produce a strategic assessment of the AI orchestration market for Q2, covering competitive positioning, market trends, and recommended actions.",
        creator: @ceo,
        assignee: @vp_strategy,
        goal: goal,
        status: :pending_review,
        priority: :medium
      )
      Message.create!(
        task: task_strategy_review,
        author: @vp_strategy,
        body: "Completed the Q2 strategic market assessment. Key findings: agent orchestration demand is accelerating, governance features are a differentiator, and our pricing should follow a hybrid model. Full analysis with recommendations attached above.",
        message_type: :comment
      )

      puts "#{TAG}   Goals and tasks seeded."
    end

    # ─── Helpers ──────────────────────────────────────────────────────

    def create_role(title, category, description:, parent:, budget:, adapter_config:)
      role = @project.roles.find_by(title: title)
      if role
        puts "#{TAG}   Found #{title} (id: #{role.id})"
        return role
      end

      role = Role.create!(
        project: @project,
        title: title,
        description: description,
        role_category: category,
        parent: parent,
        adapter_type: :claude_local,
        adapter_config: adapter_config,
        status: :idle,
        budget_cents: budget,
        budget_period_start: Date.current.beginning_of_month
      )
      puts "#{TAG}   Created #{title} (id: #{role.id}, category: #{category.name})"
      role
    end

    # ─── Verification ────────────────────────────────────────────────

    def verify
      puts "#{TAG} Verifying..."
      warnings = []

      aim_roles = @project.roles.where("description LIKE ?", "%#{TAG}%").count
      warnings << "Expected 6 roles, found #{aim_roles}" unless aim_roles == 6

      aim_goals = @project.goals.where("description LIKE ?", "%#{TAG}%").count
      warnings << "Expected 1 goal, found #{aim_goals}" unless aim_goals == 1

      aim_tasks = @project.tasks.where("description LIKE ?", "%#{TAG}%").count
      warnings << "Expected 12 tasks, found #{aim_tasks}" unless aim_tasks == 12

      if warnings.any?
        warnings.each { |w| puts "#{TAG}   WARNING: #{w}" }
      else
        puts "#{TAG}   All checks passed."
      end
    end
end
