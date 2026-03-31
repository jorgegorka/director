# db/seeds.rb
#
# Seeds "Director AI" — a self-referential company that uses Director to improve itself.
# Run: bin/rails db:seed
# This REPLACES all existing data.

puts "Seeding Director AI..."

ActiveRecord::Base.transaction do
Session.destroy_all
User.destroy_all
Company.destroy_all

user = User.create!(
  email_address: "admin@director.ai",
  password: "password123"
)

company = Company.create!(name: "Director AI")
# after_create callback auto-seeds builtin skills

Membership.create!(user: user, company: company, role: :owner)

puts "  Created user: admin@director.ai"
puts "  Created company: Director AI (#{company.skills.count} builtin skills)"

# Roles — create hierarchy with agent configuration merged directly
role_defs = [
  { title: "CEO",                description: "Sets company vision, approves budgets, and drives strategic direction.",         job_spec: "You are an experienced and skilled CEO. Your responsibilities:\n1. Perform the goals assigned to you efficiently and thoroughly.\n2. Optimise the use of your assigned budget — minimise spend while maximising output.\n3. Evaluate reports from your direct reportees and make decisions based on those reports and your assigned goals.", parent: nil,   adapter_type: :claude_local, status: :running, budget_cents: 200_000 },
  { title: "CTO",                description: "Oversees engineering team, defines technical architecture and standards.",       job_spec: "You are an experienced and skilled CTO.\n\nYour responsibilities:\n1. Perform the technical goals assigned to you efficiently and thoroughly.\n2. Optimise the use of your assigned budget — minimise spend while maximising output.\n3. Evaluate reports from your direct reportees and make decisions based on those reports and your assigned goals.\n4. Check which direct reportees you can hire, then hire the best suitable role for the job. You don't do the work yourself.\n5. Use the strategic_planning skill to decide how to perform your assigned goal(s).", parent: "CEO", adapter_type: :claude_local, status: :running, budget_cents: 150_000 },
  { title: "Engineer",           description: "Implements features, fixes bugs, and writes tests for the backend.",             job_spec: "Build and maintain Director's Rails backend.",                           parent: "CTO", adapter_type: :claude_local, status: :running, budget_cents: 80_000 },
  { title: "Designer",           description: "Builds user interfaces, implements responsive layouts and CSS architecture.",    job_spec: "Create Director's frontend experience and landing page.",                parent: "CTO", adapter_type: :claude_local, status: :running, budget_cents: 80_000 },
  { title: "Security Engineer",  description: "Conducts security audits, dependency scans, and reviews authentication flows.", job_spec: "Keep Director secure and free of vulnerabilities.",                      parent: "CTO", adapter_type: :claude_local, status: :idle,    budget_cents: 50_000 },
  { title: "DevOps",             description: "Manages CI/CD pipelines, deployment automation, and monitoring.",                job_spec: "Ensure Director deploys reliably and stays online.",                     parent: "CTO", adapter_type: :claude_local, status: :running, budget_cents: 60_000 },
  { title: "QA",                 description: "Plans test strategies, writes test suites, and enforces quality standards.",     job_spec: "Ensure Director ships with high quality and zero regressions.",          parent: "CTO", adapter_type: :claude_local, status: :idle,    budget_cents: 40_000 },
  { title: "PM",                 description: "Defines product roadmap, gathers requirements, and manages sprint cycles.",     job_spec: "Ensure Director builds the right features in the right order.",          parent: "CEO", adapter_type: :claude_local, status: :running, budget_cents: 100_000 },
  { title: "Researcher",         description: "Conducts user interviews, competitive analysis, and usability testing.",        job_spec: "Understand users and competitors to inform Director's product strategy.", parent: "CEO", adapter_type: :claude_local, status: :idle,    budget_cents: 40_000 }
]

roles = {}
role_defs.each do |attrs|
  parent_role = attrs[:parent] ? roles.fetch(attrs[:parent]) : nil
  roles[attrs[:title]] = Role.create!(
    company: company,
    title: attrs[:title],
    description: attrs[:description],
    job_spec: attrs[:job_spec],
    parent: parent_role,
    adapter_type: attrs[:adapter_type],
    adapter_config: { "model" => "claude-sonnet-4-20250514" },
    status: attrs[:status],
    budget_cents: attrs[:budget_cents],
    budget_period_start: Date.current.beginning_of_month
  )
end

puts "  Created #{roles.size} roles in hierarchy (with agent configuration)"

# Marketing department — roles created from template for consistent job_specs
marketing_template = RoleTemplates::Registry.find("marketing")
marketing_roles_by_title = marketing_template.roles.index_by(&:title)

marketing_role_configs = [
  { title: "CMO",                     parent: "CEO",               status: :running, budget_cents: 120_000 },
  { title: "Marketing Planner",       parent: "CMO",               status: :running, budget_cents: 60_000 },
  { title: "Web Analyst",             parent: "Marketing Planner",  status: :idle,    budget_cents: 30_000 },
  { title: "SEO Specialist",          parent: "Marketing Planner",  status: :running, budget_cents: 30_000 },
  { title: "Marketing Manager",       parent: "CMO",               status: :running, budget_cents: 60_000 },
  { title: "LinkedIn Specialist",     parent: "Marketing Manager",  status: :idle,    budget_cents: 25_000 },
  { title: "Blog Content Specialist", parent: "Marketing Manager",  status: :running, budget_cents: 40_000 },
  { title: "Page Specialist",         parent: "Marketing Manager",  status: :running, budget_cents: 40_000 },
  { title: "Email Specialist",        parent: "Marketing Manager",  status: :idle,    budget_cents: 25_000 }
]

marketing_role_configs.each do |config|
  template_role = marketing_roles_by_title.fetch(config[:title])
  parent_role = roles.fetch(config[:parent])
  roles[config[:title]] = Role.create!(
    company: company,
    title: config[:title],
    description: template_role.description,
    job_spec: template_role.job_spec,
    parent: parent_role,
    adapter_type: :claude_local,
    adapter_config: { "model" => "claude-sonnet-4-20250514" },
    status: config[:status],
    budget_cents: config[:budget_cents],
    budget_period_start: Date.current.beginning_of_month
  )
end

puts "  Created #{marketing_role_configs.size} marketing roles from template"
puts "  Auto-assigned skills for matching role titles"

# Manual skill assignments for roles that don't match default_skills.yml keys
manual_skill_assignments = {
  "Security Engineer" => %w[security_assessment code_review risk_assessment monitoring_alerting incident_response]
}

all_skill_keys = manual_skill_assignments.values.flatten.uniq
skills_by_key = company.skills.where(key: all_skill_keys).index_by(&:key)
missing = all_skill_keys - skills_by_key.keys
raise "Missing skills: #{missing.join(', ')}" if missing.any?

manual_skill_assignments.each do |role_title, skill_keys|
  role = roles[role_title]
  skill_keys.each { |key| role.role_skills.find_or_create_by!(skill: skills_by_key.fetch(key)) }
end

puts "  Manually assigned skills to Security Engineer"

mission = Goal.create!(
  company: company,
  title: "Make Director the best AI orchestration platform",
  description: "Our mission is to build the most powerful, intuitive, and reliable platform for orchestrating AI agent companies.",
  position: 0
)

objectives = {}

objectives["marketing"] = Goal.create!(
  company: company, parent: mission, position: 0,
  title: "Launch public marketing website",
  description: "Build and launch a compelling public-facing website that communicates Director's value proposition."
)

objectives["product"] = Goal.create!(
  company: company, parent: mission, position: 1,
  title: "Deliver excellent product experience",
  description: "Understand users deeply and ship features that solve real problems."
)

objectives["engineering"] = Goal.create!(
  company: company, parent: mission, position: 2,
  title: "Build a robust and secure platform",
  description: "Ensure Director is reliable, secure, and performant at every layer."
)

objectives["infrastructure"] = Goal.create!(
  company: company, parent: mission, position: 3,
  title: "Ship reliable infrastructure",
  description: "Automate deployments, monitoring, and incident response for zero-downtime operations."
)

sub_objectives = {}

sub_objectives["landing_page"] = Goal.create!(
  company: company, parent: objectives["marketing"], position: 0,
  title: "Build landing page with compelling value proposition",
  description: "Design and implement a high-converting landing page."
)

sub_objectives["seo"] = Goal.create!(
  company: company, parent: objectives["marketing"], position: 1,
  title: "Implement SEO strategy for organic growth",
  description: "Research keywords, optimize metadata, and improve search rankings."
)

sub_objectives["content_pipeline"] = Goal.create!(
  company: company, parent: objectives["marketing"], position: 2,
  title: "Create content marketing pipeline",
  description: "Establish a blog, content calendar, and email capture workflow."
)

sub_objectives["feedback_loop"] = Goal.create!(
  company: company, parent: objectives["product"], position: 0,
  title: "Establish user feedback loop",
  description: "Conduct interviews, define KPIs, and create feedback channels."
)

sub_objectives["product_roadmap"] = Goal.create!(
  company: company, parent: objectives["product"], position: 1,
  title: "Define and prioritize product roadmap",
  description: "Write requirements, prioritize features, and plan quarterly milestones."
)

sub_objectives["competitive_analysis"] = Goal.create!(
  company: company, parent: objectives["product"], position: 2,
  title: "Conduct competitive analysis",
  description: "Map competitor features and identify differentiation opportunities."
)

sub_objectives["test_coverage"] = Goal.create!(
  company: company, parent: objectives["engineering"], position: 0,
  title: "Achieve comprehensive test coverage",
  description: "Write controller and model tests for all critical paths."
)

sub_objectives["security_audit"] = Goal.create!(
  company: company, parent: objectives["engineering"], position: 1,
  title: "Pass security audit with zero critical findings",
  description: "Run OWASP scans, audit auth flows, and fix all vulnerabilities."
)

sub_objectives["performance"] = Goal.create!(
  company: company, parent: objectives["engineering"], position: 2,
  title: "Optimize performance to sub-200ms response times",
  description: "Fix N+1 queries, add caching, and benchmark all endpoints."
)

sub_objectives["ci_cd"] = Goal.create!(
  company: company, parent: objectives["infrastructure"], position: 0,
  title: "Automate CI/CD pipeline",
  description: "Configure GitHub Actions, staging environments, and zero-downtime deploys."
)

sub_objectives["monitoring"] = Goal.create!(
  company: company, parent: objectives["infrastructure"], position: 1,
  title: "Set up monitoring and alerting",
  description: "Configure error monitoring, uptime alerting, and performance dashboards."
)

puts "  Created goal tree: 1 mission, #{objectives.size} objectives, #{sub_objectives.size} sub-objectives"

tasks = {}

# Backdates completed tasks for a realistic timeline
def create_task!(company, user, attrs)
  completed_ago = attrs.delete(:completed_ago)
  task = Task.create!(company: company, creator: user, **attrs)
  if task.completed? && completed_ago
    completed_at = completed_ago.ago
    task.update_columns(completed_at: completed_at, created_at: completed_at - 2.days)
  end
  task
end

# --- Marketing Tasks ---

tasks["design_wireframes"] = create_task!(company, user,
  assignee: roles["Page Specialist"],
  goal: sub_objectives["landing_page"],
  title: "Design landing page wireframes",
  description: "Create wireframes for the marketing landing page including hero section, features grid, pricing, and CTA.",
  status: :completed, priority: :high, cost_cents: 4500, completed_ago: 10.days
)

tasks["implement_landing"] = create_task!(company, user,
  assignee: roles["Designer"],
  goal: sub_objectives["landing_page"],
  title: "Implement landing page HTML/CSS",
  description: "Build the landing page from wireframes using semantic HTML and the project's CSS architecture with OKLCH colors.",
  status: :in_progress, priority: :high, cost_cents: 12_000
)

tasks["responsive_styles"] = create_task!(company, user,
  assignee: roles["Designer"],
  goal: sub_objectives["landing_page"],
  parent_task: tasks["implement_landing"],
  title: "Add responsive mobile styles",
  description: "Ensure the landing page renders correctly on mobile devices with proper breakpoints.",
  status: :open, priority: :medium
)

tasks["optimize_images"] = create_task!(company, user,
  assignee: roles["Designer"],
  goal: sub_objectives["landing_page"],
  parent_task: tasks["implement_landing"],
  title: "Optimize hero section images",
  description: "Compress and serve responsive images for the hero section using modern formats.",
  status: :open, priority: :low
)

tasks["write_copy"] = create_task!(company, user,
  assignee: roles["Page Specialist"],
  goal: sub_objectives["landing_page"],
  title: "Write landing page copy",
  description: "Write compelling headlines, feature descriptions, and CTA copy for the landing page.",
  status: :completed, priority: :medium, cost_cents: 3000, completed_ago: 8.days
)

tasks["research_keywords"] = create_task!(company, user,
  assignee: roles["SEO Specialist"],
  goal: sub_objectives["seo"],
  title: "Research target keywords",
  description: "Identify high-value keywords related to AI orchestration, agent management, and AI companies.",
  status: :completed, priority: :medium, cost_cents: 1500, completed_ago: 12.days
)

tasks["implement_meta"] = create_task!(company, user,
  assignee: roles["SEO Specialist"],
  goal: sub_objectives["seo"],
  title: "Implement meta tags and structured data",
  description: "Add title tags, meta descriptions, Open Graph tags, and JSON-LD structured data to all public pages.",
  status: :in_progress, priority: :medium, cost_cents: 2000
)

tasks["content_calendar"] = create_task!(company, user,
  assignee: roles["Blog Content Specialist"],
  goal: sub_objectives["content_pipeline"],
  title: "Create blog content calendar",
  description: "Plan 3 months of blog content covering AI orchestration topics, tutorials, and case studies.",
  status: :open, priority: :medium
)

tasks["analytics"] = create_task!(company, user,
  assignee: roles["Web Analyst"],
  goal: sub_objectives["seo"],
  title: "Set up analytics tracking",
  description: "Configure privacy-respecting analytics to track landing page conversions and traffic sources.",
  status: :open, priority: :high
)

tasks["marketing_audit"] = create_task!(company, user,
  assignee: roles["Marketing Planner"],
  goal: objectives["marketing"],
  title: "Evaluate current marketing performance",
  description: "Assess website traffic, SEO rankings, and content performance. Prepare a situational analysis with prioritised recommendations for Q2.",
  status: :in_progress, priority: :high, cost_cents: 3000
)

tasks["coordinate_landing"] = create_task!(company, user,
  assignee: roles["Marketing Manager"],
  goal: sub_objectives["landing_page"],
  title: "Coordinate landing page launch",
  description: "Break down the landing page launch into atomic tasks, assign to specialists, and ensure all deliverables meet quality standards before go-live.",
  status: :in_progress, priority: :high, cost_cents: 2000
)

tasks["email_capture"] = create_task!(company, user,
  assignee: roles["Designer"],
  goal: sub_objectives["content_pipeline"],
  title: "Design email capture flow",
  description: "Build an email signup form with validation and a thank-you confirmation flow.",
  status: :blocked, priority: :medium
)

# --- Product Tasks ---

tasks["write_prd"] = create_task!(company, user,
  assignee: roles["PM"],
  goal: sub_objectives["product_roadmap"],
  title: "Write product requirements document",
  description: "Document detailed requirements for Director v2 including user stories, acceptance criteria, and priorities.",
  status: :completed, priority: :high, cost_cents: 3500, completed_ago: 14.days
)

tasks["competitor_matrix"] = create_task!(company, user,
  assignee: roles["Researcher"],
  goal: sub_objectives["competitive_analysis"],
  title: "Map competitor feature matrix",
  description: "Analyze competing AI orchestration platforms and map their features against Director's capabilities.",
  status: :completed, priority: :medium, cost_cents: 2500, completed_ago: 11.days
)

tasks["user_interviews"] = create_task!(company, user,
  assignee: roles["Researcher"],
  goal: sub_objectives["feedback_loop"],
  title: "Conduct user interviews",
  description: "Interview 10 potential users to understand their pain points with current AI management tools.",
  status: :in_progress, priority: :high, cost_cents: 4000
)

tasks["prioritize_roadmap"] = create_task!(company, user,
  assignee: roles["PM"],
  goal: sub_objectives["product_roadmap"],
  title: "Prioritize Q2 roadmap",
  description: "Stack-rank features for Q2 based on user interview findings and competitive analysis.",
  status: :open, priority: :urgent
)

tasks["define_kpis"] = create_task!(company, user,
  assignee: roles["PM"],
  goal: sub_objectives["feedback_loop"],
  title: "Define success metrics and KPIs",
  description: "Establish measurable KPIs for Director including activation rate, retention, and task completion rates.",
  status: :in_progress, priority: :medium, cost_cents: 1500
)

tasks["user_personas"] = create_task!(company, user,
  assignee: roles["Researcher"],
  goal: sub_objectives["feedback_loop"],
  title: "Create user persona documents",
  description: "Synthesize interview findings into 3-4 detailed user personas for Director's target audience.",
  status: :open, priority: :medium
)

# --- Engineering Tasks ---

tasks["rate_limiting"] = create_task!(company, user,
  assignee: roles["Engineer"],
  goal: sub_objectives["performance"],
  title: "Implement API rate limiting",
  description: "Add rate limiting to the agent API endpoints to prevent abuse and ensure fair usage.",
  status: :completed, priority: :high, cost_cents: 6000, completed_ago: 7.days
)

tasks["input_validation"] = create_task!(company, user,
  assignee: roles["Engineer"],
  goal: sub_objectives["security_audit"],
  title: "Add request input validation",
  description: "Add strong parameter validation and input sanitization to all controller actions.",
  status: :completed, priority: :medium, cost_cents: 4000, completed_ago: 5.days
)

tasks["fix_n1"] = create_task!(company, user,
  assignee: roles["Engineer"],
  goal: sub_objectives["performance"],
  title: "Fix N+1 query on dashboard",
  description: "The company dashboard loads roles with N+1 queries on skills. Each role card triggers additional queries. Add proper eager loading.",
  status: :in_progress, priority: :urgent, cost_cents: 2500
)

tasks["owasp_scan"] = create_task!(company, user,
  assignee: roles["Security Engineer"],
  goal: sub_objectives["security_audit"],
  title: "Run OWASP dependency scan",
  description: "Run bundler-audit and importmap audit to identify vulnerable dependencies.",
  status: :completed, priority: :high, cost_cents: 2000, completed_ago: 4.days
)

tasks["audit_auth"] = create_task!(company, user,
  assignee: roles["Security Engineer"],
  goal: sub_objectives["security_audit"],
  title: "Audit authentication flow",
  description: "Review the authentication implementation for session fixation, timing attacks, and token management issues.",
  status: :in_progress, priority: :urgent, cost_cents: 3500
)

tasks["controller_tests"] = create_task!(company, user,
  assignee: roles["QA"],
  goal: sub_objectives["test_coverage"],
  title: "Write controller test suite",
  description: "Write comprehensive controller tests for all resources including auth, roles, tasks, and goals.",
  status: :in_progress, priority: :high, cost_cents: 5000
)

tasks["perf_benchmarks"] = create_task!(company, user,
  assignee: roles["QA"],
  goal: sub_objectives["performance"],
  title: "Set up performance benchmarks",
  description: "Create benchmark tests for critical endpoints to track response time regressions.",
  status: :open, priority: :medium
)

tasks["design_tokens"] = create_task!(company, user,
  assignee: roles["Designer"],
  goal: sub_objectives["landing_page"],
  title: "Refactor CSS to use design tokens",
  description: "Extract repeated color and spacing values into CSS custom properties for consistency.",
  status: :open, priority: :low
)

# --- DevOps Tasks ---

tasks["ci_pipeline"] = create_task!(company, user,
  assignee: roles["DevOps"],
  goal: sub_objectives["ci_cd"],
  title: "Configure GitHub Actions CI pipeline",
  description: "Set up GitHub Actions to run rubocop, brakeman, and the full test suite on every push.",
  status: :completed, priority: :high, cost_cents: 3000, completed_ago: 13.days
)

tasks["staging_env"] = create_task!(company, user,
  assignee: roles["DevOps"],
  goal: sub_objectives["ci_cd"],
  title: "Set up staging environment",
  description: "Deploy a staging environment with Kamal that mirrors production for pre-release testing.",
  status: :completed, priority: :high, cost_cents: 4500, completed_ago: 9.days
)

tasks["zero_downtime"] = create_task!(company, user,
  assignee: roles["DevOps"],
  goal: sub_objectives["ci_cd"],
  title: "Implement zero-downtime deploys",
  description: "Configure Kamal for rolling deploys with health checks to achieve zero-downtime releases.",
  status: :in_progress, priority: :medium, cost_cents: 5500
)

tasks["error_monitoring"] = create_task!(company, user,
  assignee: roles["DevOps"],
  goal: sub_objectives["monitoring"],
  title: "Configure error monitoring",
  description: "Set up error tracking to capture and alert on unhandled exceptions in production.",
  status: :open, priority: :high
)

tasks["uptime_alerting"] = create_task!(company, user,
  assignee: roles["DevOps"],
  goal: sub_objectives["monitoring"],
  title: "Set up uptime alerting",
  description: "Configure uptime monitoring with alerts for downtime and degraded performance.",
  status: :open, priority: :medium
)

# --- Leadership Tasks ---

tasks["tech_debt"] = create_task!(company, user,
  assignee: roles["CTO"],
  goal: objectives["engineering"],
  title: "Review Q1 technical debt report",
  description: "Review accumulated technical debt from Q1 and prioritize items for Q2 cleanup.",
  status: :completed, priority: :medium, cost_cents: 1000, completed_ago: 3.days
)

tasks["approve_budget"] = create_task!(company, user,
  assignee: roles["CEO"],
  goal: objectives["marketing"],
  title: "Approve marketing budget allocation",
  description: "Review and approve the proposed Q2 marketing budget for the website launch campaign.",
  status: :completed, priority: :low, cost_cents: 500, completed_ago: 6.days
)

tasks["hiring_plan"] = create_task!(company, user,
  assignee: roles["CEO"],
  goal: mission,
  title: "Define hiring plan for Q3",
  description: "Determine which additional roles are needed to scale Director's capabilities in Q3.",
  status: :open, priority: :medium
)

completed_count = tasks.values.count { |t| t.completed? }
puts "  Created #{tasks.size} tasks (#{completed_count} completed, #{tasks.size - completed_count} active)"

m1 = Message.create!(
  task: tasks["fix_n1"], author: roles["Engineer"],
  body: "Found the issue. The dashboard controller loads roles without eager loading skills. Each role card triggers 2 additional queries. With 12 roles that's 24 extra queries per page load."
)
Message.create!(
  task: tasks["fix_n1"], author: roles["CTO"], parent: m1,
  body: "What's the measured impact on response time? We should benchmark before and after so we can quantify the improvement."
)
Message.create!(
  task: tasks["fix_n1"], author: roles["Engineer"], parent: m1,
  body: "Current p50 is 340ms, p95 is 890ms. With includes(:skills) it drops to p50 45ms, p95 120ms. Will push the fix today."
)

m2 = Message.create!(
  task: tasks["audit_auth"], author: roles["Security Engineer"],
  body: "Initial review found that session tokens are not rotated after password changes. This means a compromised session stays valid even after the user resets their password."
)
Message.create!(
  task: tasks["audit_auth"], author: user, parent: m2,
  body: "Good catch. What's your timeline for fixing this and completing the full audit?"
)
Message.create!(
  task: tasks["audit_auth"], author: roles["Security Engineer"], parent: m2,
  body: "Session rotation fix is straightforward — I can ship that today. Full audit including CSRF and timing attack review will take about 2 more days."
)

m3 = Message.create!(
  task: tasks["user_interviews"], author: roles["Researcher"],
  body: "Completed 4 of 10 interviews so far. Early pattern: users want better visibility into agent decision-making. The audit trail is valued but they want real-time explanations, not just after-the-fact logs."
)
Message.create!(
  task: tasks["user_interviews"], author: roles["PM"], parent: m3,
  body: "Interesting insight. Can you expand the interview script to dig deeper into what 'real-time explanations' means to them? Also consider adding 2-3 more participants from the enterprise segment."
)

m4 = Message.create!(
  task: tasks["implement_landing"], author: roles["Designer"],
  body: "Starting implementation. The wireframes show a 3-column features grid — should I use CSS Grid or Flexbox? Grid gives us more control over the layout but Flexbox is simpler for this use case."
)
Message.create!(
  task: tasks["implement_landing"], author: roles["CMO"], parent: m4,
  body: "Use CSS Grid — we'll likely add more feature cards later and Grid handles reflow better. Here's the final wireframe with the approved color palette from the style guide."
)
Message.create!(
  task: tasks["implement_landing"], author: roles["Designer"], parent: m4,
  body: "Sounds good. Going with Grid and using the OKLCH color tokens from our design system. Will have the hero section and features grid ready for review by end of day."
)

m5 = Message.create!(
  task: tasks["zero_downtime"], author: roles["DevOps"],
  body: "Proposing blue-green deployment with Kamal. We run two identical environments and swap traffic after health checks pass. Rollback is instant — just swap back. The tradeoff is we need double the server resources during deploys."
)
Message.create!(
  task: tasks["zero_downtime"], author: roles["CTO"], parent: m5,
  body: "Blue-green is the right call. The resource overhead during deploys is acceptable given our scale. Go ahead with this approach."
)

message_count = Message.where(task: tasks.values).count
puts "  Created #{message_count} messages across 5 task threads"

gate_defs = {
  "Engineer"          => %w[budget_spend task_creation],
  "Security Engineer" => %w[status_change escalation],
  "DevOps"            => %w[task_delegation budget_spend],
  "CEO"               => %w[budget_spend]
}

gate_count = 0
gate_defs.each do |role_title, action_types|
  action_types.each do |action_type|
    ApprovalGate.create!(
      role: roles[role_title],
      action_type: action_type,
      enabled: true
    )
    gate_count += 1
  end
end

puts "  Created #{gate_count} approval gates"

# Audit events — backdated for realistic activity timeline
def create_audit_event!(attrs)
  days_ago = attrs.delete(:days_ago) || 0
  event = AuditEvent.create!(attrs)
  AuditEvent.where(id: event.id).update_all(created_at: days_ago.days.ago) if days_ago > 0
  event
end

create_audit_event!(
  company: company, auditable: roles["CEO"], actor: user,
  action: "agent_resumed", metadata: { status: "running" }, days_ago: 14
)

create_audit_event!(
  company: company, auditable: roles["Security Engineer"], actor: roles["Security Engineer"],
  action: "agent_paused", metadata: { reason: "Completed OWASP scan, awaiting next assignment" }, days_ago: 4
)

create_audit_event!(
  company: company, auditable: roles["Security Engineer"], actor: user,
  action: "agent_resumed", metadata: { status: "idle" }, days_ago: 4
)

create_audit_event!(
  company: company, auditable: roles["Engineer"], actor: user,
  action: "gate_approval", metadata: { gate: "budget_spend", amount_cents: 6000, task: "Implement API rate limiting" }, days_ago: 7
)

create_audit_event!(
  company: company, auditable: roles["DevOps"], actor: roles["CTO"],
  action: "gate_approval", metadata: { gate: "task_delegation", task: "Set up staging environment" }, days_ago: 9
)

create_audit_event!(
  company: company, auditable: roles["Security Engineer"], actor: roles["CTO"],
  action: "gate_rejection", metadata: { gate: "escalation", reason: "Escalation not warranted — handle within team" }, days_ago: 6
)

create_audit_event!(
  company: company, auditable: tasks["rate_limiting"], actor: roles["Engineer"],
  action: "cost_recorded", metadata: { cost_cents: 6000, task: "Implement API rate limiting" }, days_ago: 7
)

create_audit_event!(
  company: company, auditable: tasks["ci_pipeline"], actor: roles["DevOps"],
  action: "cost_recorded", metadata: { cost_cents: 3000, task: "Configure GitHub Actions CI pipeline" }, days_ago: 13
)

create_audit_event!(
  company: company, auditable: tasks["staging_env"], actor: roles["DevOps"],
  action: "cost_recorded", metadata: { cost_cents: 4500, task: "Set up staging environment" }, days_ago: 9
)

create_audit_event!(
  company: company, auditable: roles["CTO"], actor: user,
  action: "config_rollback",
  metadata: { attribute: "budget_cents", old_value: 100_000, new_value: 150_000, reason: "Increased budget for Q2 technical initiatives" },
  days_ago: 10
)

create_audit_event!(
  company: company, auditable: roles["QA"], actor: user,
  action: "emergency_stop", metadata: { reason: "Paused for test configuration fix" }, days_ago: 2
)

create_audit_event!(
  company: company, auditable: roles["QA"], actor: user,
  action: "emergency_resume", metadata: { reason: "Configuration fixed, resuming test execution" }, days_ago: 2
)

create_audit_event!(
  company: company, auditable: roles["Engineer"], actor: roles["Engineer"],
  action: "gate_blocked", metadata: { gate: "budget_spend", amount_cents: 8000, task: "Fix N+1 query on dashboard", reason: "Pending approval" }, days_ago: 1
)

create_audit_event!(
  company: company, auditable: tasks["owasp_scan"], actor: roles["Security Engineer"],
  action: "cost_recorded", metadata: { cost_cents: 2000, task: "Run OWASP dependency scan" }, days_ago: 4
)

create_audit_event!(
  company: company, auditable: tasks["design_wireframes"], actor: roles["Page Specialist"],
  action: "cost_recorded", metadata: { cost_cents: 4500, task: "Design landing page wireframes" }, days_ago: 10
)

audit_count = AuditEvent.where(company: company).count
puts "  Created #{audit_count} audit events"

def create_notification!(attrs)
  days_ago = attrs.delete(:days_ago) || 0
  mark_read = attrs.delete(:read) || false
  notif = Notification.create!(attrs)
  updates = {}
  updates[:created_at] = days_ago.days.ago if days_ago > 0
  updates[:read_at] = (days_ago.days.ago + 1.hour) if mark_read
  notif.update_columns(updates) if updates.any?
  notif
end

# Unread notifications (8)
create_notification!(
  company: company, recipient: user, actor: roles["Engineer"],
  notifiable: roles["Engineer"],
  action: "budget_threshold_alert",
  metadata: { role_title: "Engineer", utilization: 75, budget_cents: 80_000, spent_cents: 60_000 },
  days_ago: 1
)

create_notification!(
  company: company, recipient: user, actor: roles["DevOps"],
  notifiable: roles["DevOps"],
  action: "gate_approval_requested",
  metadata: { role_title: "DevOps", gate: "budget_spend", task: "Implement zero-downtime deploys" },
  days_ago: 1
)

create_notification!(
  company: company, recipient: user, actor: roles["Security Engineer"],
  notifiable: roles["Security Engineer"],
  action: "gate_approval_requested",
  metadata: { role_title: "Security Engineer", gate: "status_change", task: "Audit authentication flow" },
  days_ago: 2
)

create_notification!(
  company: company, recipient: user, actor: roles["Security Engineer"],
  notifiable: tasks["owasp_scan"],
  action: "task_completed",
  metadata: { task_title: "Run OWASP dependency scan", role_title: "Security Engineer" },
  days_ago: 4
)

create_notification!(
  company: company, recipient: user, actor: roles["DevOps"],
  notifiable: tasks["staging_env"],
  action: "task_completed",
  metadata: { task_title: "Set up staging environment", role_title: "DevOps" },
  days_ago: 9
)

create_notification!(
  company: company, recipient: user, actor: roles["Security Engineer"],
  notifiable: roles["Security Engineer"],
  action: "role_status_changed",
  metadata: { role_title: "Security Engineer", old_status: "running", new_status: "idle" },
  days_ago: 4
)

create_notification!(
  company: company, recipient: user, actor: roles["QA"],
  notifiable: roles["QA"],
  action: "role_status_changed",
  metadata: { role_title: "QA", old_status: "paused", new_status: "idle" },
  days_ago: 2
)

create_notification!(
  company: company, recipient: user, actor: roles["PM"],
  notifiable: tasks["prioritize_roadmap"],
  action: "task_assigned",
  metadata: { task_title: "Prioritize Q2 roadmap", role_title: "PM" },
  days_ago: 1
)

# Read notifications (5)
create_notification!(
  company: company, recipient: user, actor: roles["CEO"],
  notifiable: tasks["approve_budget"],
  action: "task_completed",
  metadata: { task_title: "Approve marketing budget allocation", role_title: "CEO" },
  days_ago: 6, read: true
)

create_notification!(
  company: company, recipient: user, actor: user,
  notifiable: roles["CTO"],
  action: "config_updated",
  metadata: { role_title: "CTO", attribute: "budget_cents", old_value: 100_000, new_value: 150_000 },
  days_ago: 10, read: true
)

create_notification!(
  company: company, recipient: user, actor: user,
  notifiable: roles["Engineer"],
  action: "gate_approved",
  metadata: { role_title: "Engineer", gate: "budget_spend", task: "Implement API rate limiting" },
  days_ago: 7, read: true
)

create_notification!(
  company: company, recipient: user, actor: roles["Engineer"],
  notifiable: tasks["rate_limiting"],
  action: "task_completed",
  metadata: { task_title: "Implement API rate limiting", role_title: "Engineer" },
  days_ago: 7, read: true
)

create_notification!(
  company: company, recipient: user, actor: roles["Page Specialist"],
  notifiable: tasks["design_wireframes"],
  action: "task_completed",
  metadata: { task_title: "Design landing page wireframes", role_title: "Page Specialist" },
  days_ago: 10, read: true
)

notif_count = Notification.where(company: company).count
unread_count = Notification.where(company: company).unread.count
puts "  Created #{notif_count} notifications (#{unread_count} unread)"

running = roles.values.count { |r| r.running? }
idle = roles.values.count { |r| r.idle? }
skill_count = company.skills.count
builtin_count = company.skills.builtin.count
goal_count = 1 + objectives.size + sub_objectives.size

puts ""
puts "=" * 60
puts "  Director AI seeded successfully!"
puts "=" * 60
puts ""
puts "  Login:    admin@director.ai / password123"
puts ""
puts "  Company:  #{company.name}"
puts "  Roles:    #{roles.size} (#{running} running, #{idle} idle)"
puts "  Skills:   #{skill_count} (#{builtin_count} builtin)"
puts "  Goals:    #{goal_count} (1 mission, #{objectives.size + sub_objectives.size} sub-goals)"
puts "  Tasks:    #{tasks.size} (#{completed_count} completed)"
puts "  Messages: #{message_count}"
puts "  Gates:    #{gate_count}"
puts "  Audits:   #{audit_count}"
puts "  Alerts:   #{notif_count} (#{unread_count} unread)"
puts ""
end # transaction
