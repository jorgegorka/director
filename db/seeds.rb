# db/seeds.rb
#
# Seeds "Director AI" — a self-referential company that uses Director to improve itself.
# Run: bin/rails db:seed
# This REPLACES all existing data.

puts "Seeding Director AI..."

# Clean slate
Session.destroy_all
User.destroy_all
Company.destroy_all

# User & Company
user = User.create!(
  email_address: "admin@director.ai",
  password: "password123"
)

company = Company.create!(name: "Director AI")
# ↑ after_create callback auto-seeds 50 builtin skills

Membership.create!(user: user, company: company, role: :owner)

puts "  Created user: admin@director.ai"
puts "  Created company: Director AI (#{company.skills.count} builtin skills)"

# Agents
agent_defs = [
  { name: "CEO",                adapter_type: :claude_local, status: :running, budget_cents: 200_000, description: "Chief Executive Officer. Sets company vision and strategy." },
  { name: "CTO",                adapter_type: :claude_local, status: :running, budget_cents: 150_000, description: "Chief Technology Officer. Oversees all engineering and technical strategy." },
  { name: "Backend Engineer",   adapter_type: :claude_local, status: :running, budget_cents: 80_000,  description: "Implements server-side features, fixes bugs, and optimizes performance." },
  { name: "Frontend Engineer",  adapter_type: :claude_local, status: :running, budget_cents: 80_000,  description: "Builds user interfaces, implements landing pages, and manages CSS architecture." },
  { name: "Security Engineer",  adapter_type: :claude_local, status: :idle,    budget_cents: 50_000,  description: "Conducts security audits, dependency scans, and authentication reviews." },
  { name: "DevOps Engineer",    adapter_type: :claude_local, status: :running, budget_cents: 60_000,  description: "Manages CI/CD pipelines, deployment automation, and infrastructure." },
  { name: "QA Engineer",        adapter_type: :claude_local, status: :idle,    budget_cents: 40_000,  description: "Plans and executes test suites, tracks quality metrics." },
  { name: "CMO",                adapter_type: :claude_local, status: :running, budget_cents: 120_000, description: "Chief Marketing Officer. Drives marketing strategy and brand presence." },
  { name: "SEO Specialist",     adapter_type: :claude_local, status: :idle,    budget_cents: 30_000,  description: "Optimizes search engine rankings, manages keywords and metadata." },
  { name: "Content Strategist", adapter_type: :claude_local, status: :running, budget_cents: 50_000,  description: "Creates content calendars, writes blog posts, and manages brand voice." },
  { name: "Product Manager",    adapter_type: :claude_local, status: :running, budget_cents: 100_000, description: "Defines product roadmap, gathers requirements, and manages sprints." },
  { name: "UX Researcher",      adapter_type: :claude_local, status: :idle,    budget_cents: 40_000,  description: "Conducts user interviews, competitive analysis, and usability testing." }
]

agents = {}
agent_defs.each do |attrs|
  agents[attrs[:name]] = Agent.create!(
    company: company,
    adapter_config: { "model" => "claude-sonnet-4-20250514" },
    budget_period_start: Date.current.beginning_of_month,
    **attrs
  )
end

puts "  Created #{agents.size} agents"

# Roles — create hierarchy first, then assign agents to trigger skill auto-assignment
role_defs = [
  { title: "CEO",                description: "Sets company vision, approves budgets, and drives strategic direction.",         job_spec: "Lead the company to make Director the best AI orchestration platform.", parent: nil },
  { title: "CTO",                description: "Oversees engineering team, defines technical architecture and standards.",       job_spec: "Ensure Director is robust, secure, and performant.",                    parent: "CEO" },
  { title: "Engineer",           description: "Implements features, fixes bugs, and writes tests for the backend.",             job_spec: "Build and maintain Director's Rails backend.",                           parent: "CTO" },
  { title: "Designer",           description: "Builds user interfaces, implements responsive layouts and CSS architecture.",    job_spec: "Create Director's frontend experience and landing page.",                parent: "CTO" },
  { title: "Security Engineer",  description: "Conducts security audits, dependency scans, and reviews authentication flows.", job_spec: "Keep Director secure and free of vulnerabilities.",                      parent: "CTO" },
  { title: "DevOps",             description: "Manages CI/CD pipelines, deployment automation, and monitoring.",                job_spec: "Ensure Director deploys reliably and stays online.",                     parent: "CTO" },
  { title: "QA",                 description: "Plans test strategies, writes test suites, and enforces quality standards.",     job_spec: "Ensure Director ships with high quality and zero regressions.",          parent: "CTO" },
  { title: "CMO",                description: "Drives marketing strategy, brand presence, and audience growth.",                job_spec: "Make Director visible and compelling to potential users.",                parent: "CEO" },
  { title: "SEO Specialist",     description: "Optimizes search rankings through keywords, metadata, and content strategy.",   job_spec: "Drive organic traffic to Director's marketing site.",                    parent: "CMO" },
  { title: "Content Strategist", description: "Creates content calendars, writes blog posts, and maintains brand voice.",      job_spec: "Build Director's content marketing pipeline.",                           parent: "CMO" },
  { title: "PM",                 description: "Defines product roadmap, gathers requirements, and manages sprint cycles.",     job_spec: "Ensure Director builds the right features in the right order.",          parent: "CEO" },
  { title: "Researcher",         description: "Conducts user interviews, competitive analysis, and usability testing.",        job_spec: "Understand users and competitors to inform Director's product strategy.", parent: "CEO" }
]

roles = {}
role_defs.each do |attrs|
  parent_role = attrs[:parent] ? roles.fetch(attrs[:parent]) : nil
  roles[attrs[:title]] = Role.create!(
    company: company,
    title: attrs[:title],
    description: attrs[:description],
    job_spec: attrs[:job_spec],
    parent: parent_role
  )
end

# Assign agents to roles — triggers default skill auto-assignment for matching titles
role_agent_map = {
  "CEO"                => "CEO",
  "CTO"                => "CTO",
  "Engineer"           => "Backend Engineer",
  "Designer"           => "Frontend Engineer",
  "Security Engineer"  => "Security Engineer",
  "DevOps"             => "DevOps Engineer",
  "QA"                 => "QA Engineer",
  "CMO"                => "CMO",
  "SEO Specialist"     => "SEO Specialist",
  "Content Strategist" => "Content Strategist",
  "PM"                 => "Product Manager",
  "Researcher"         => "UX Researcher"
}

role_agent_map.each do |role_title, agent_name|
  roles[role_title].update!(agent: agents[agent_name])
end

puts "  Created #{roles.size} roles in hierarchy"
puts "  Auto-assigned skills for matching role titles"

# Manual skill assignments for roles that don't match default_skills.yml keys
manual_skill_assignments = {
  "Security Engineer"  => %w[security_assessment code_review risk_assessment monitoring_alerting incident_response],
  "SEO Specialist"     => %w[content_strategy market_analysis data_analysis audience_research report_writing],
  "Content Strategist" => %w[content_strategy brand_management audience_research documentation communication]
}

manual_skill_assignments.each do |agent_name, skill_keys|
  agent = agents[agent_name]
  skills_to_assign = company.skills.where(key: skill_keys)
  missing = skill_keys - skills_to_assign.pluck(:key)
  raise "Missing skills for #{agent_name}: #{missing.join(', ')}" if missing.any?
  skills_to_assign.each do |skill|
    agent.agent_skills.find_or_create_by!(skill: skill)
  end
end

puts "  Manually assigned skills to Security Engineer, SEO Specialist, Content Strategist"

# Goal tree
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

# Marketing sub-objectives
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

# Product sub-objectives
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

# Engineering sub-objectives
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

# Infrastructure sub-objectives
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

# Tasks
tasks = {}

# Helper to backdate completed tasks for realistic timeline
def create_task!(attrs)
  completed_ago = attrs.delete(:completed_ago)
  task = Task.create!(attrs)
  if task.completed? && completed_ago
    completed_at = completed_ago.ago
    task.update_columns(completed_at: completed_at, created_at: completed_at - 2.days)
  end
  task
end

# --- Marketing Tasks ---

tasks["design_wireframes"] = create_task!(
  company: company, creator: user, assignee: agents["CMO"],
  goal: sub_objectives["landing_page"],
  title: "Design landing page wireframes",
  description: "Create wireframes for the marketing landing page including hero section, features grid, pricing, and CTA.",
  status: :completed, priority: :high, cost_cents: 4500, completed_ago: 10.days
)

tasks["implement_landing"] = create_task!(
  company: company, creator: user, assignee: agents["Frontend Engineer"],
  goal: sub_objectives["landing_page"],
  title: "Implement landing page HTML/CSS",
  description: "Build the landing page from wireframes using semantic HTML and the project's CSS architecture with OKLCH colors.",
  status: :in_progress, priority: :high, cost_cents: 12_000
)

tasks["responsive_styles"] = Task.create!(
  company: company, creator: user, assignee: agents["Frontend Engineer"],
  goal: sub_objectives["landing_page"],
  parent_task: tasks["implement_landing"],
  title: "Add responsive mobile styles",
  description: "Ensure the landing page renders correctly on mobile devices with proper breakpoints.",
  status: :open, priority: :medium
)

tasks["optimize_images"] = Task.create!(
  company: company, creator: user, assignee: agents["Frontend Engineer"],
  goal: sub_objectives["landing_page"],
  parent_task: tasks["implement_landing"],
  title: "Optimize hero section images",
  description: "Compress and serve responsive images for the hero section using modern formats.",
  status: :open, priority: :low
)

tasks["write_copy"] = create_task!(
  company: company, creator: user, assignee: agents["Content Strategist"],
  goal: sub_objectives["landing_page"],
  title: "Write landing page copy",
  description: "Write compelling headlines, feature descriptions, and CTA copy for the landing page.",
  status: :completed, priority: :medium, cost_cents: 3000, completed_ago: 8.days
)

tasks["research_keywords"] = create_task!(
  company: company, creator: user, assignee: agents["SEO Specialist"],
  goal: sub_objectives["seo"],
  title: "Research target keywords",
  description: "Identify high-value keywords related to AI orchestration, agent management, and AI companies.",
  status: :completed, priority: :medium, cost_cents: 1500, completed_ago: 12.days
)

tasks["implement_meta"] = Task.create!(
  company: company, creator: user, assignee: agents["SEO Specialist"],
  goal: sub_objectives["seo"],
  title: "Implement meta tags and structured data",
  description: "Add title tags, meta descriptions, Open Graph tags, and JSON-LD structured data to all public pages.",
  status: :in_progress, priority: :medium, cost_cents: 2000
)

tasks["content_calendar"] = Task.create!(
  company: company, creator: user, assignee: agents["Content Strategist"],
  goal: sub_objectives["content_pipeline"],
  title: "Create blog content calendar",
  description: "Plan 3 months of blog content covering AI orchestration topics, tutorials, and case studies.",
  status: :open, priority: :medium
)

tasks["analytics"] = Task.create!(
  company: company, creator: user, assignee: agents["CMO"],
  goal: sub_objectives["seo"],
  title: "Set up analytics tracking",
  description: "Configure privacy-respecting analytics to track landing page conversions and traffic sources.",
  status: :open, priority: :high
)

tasks["email_capture"] = Task.create!(
  company: company, creator: user, assignee: agents["Frontend Engineer"],
  goal: sub_objectives["content_pipeline"],
  title: "Design email capture flow",
  description: "Build an email signup form with validation and a thank-you confirmation flow.",
  status: :blocked, priority: :medium
)

# --- Product Tasks ---

tasks["write_prd"] = create_task!(
  company: company, creator: user, assignee: agents["Product Manager"],
  goal: sub_objectives["product_roadmap"],
  title: "Write product requirements document",
  description: "Document detailed requirements for Director v2 including user stories, acceptance criteria, and priorities.",
  status: :completed, priority: :high, cost_cents: 3500, completed_ago: 14.days
)

tasks["competitor_matrix"] = create_task!(
  company: company, creator: user, assignee: agents["UX Researcher"],
  goal: sub_objectives["competitive_analysis"],
  title: "Map competitor feature matrix",
  description: "Analyze competing AI orchestration platforms and map their features against Director's capabilities.",
  status: :completed, priority: :medium, cost_cents: 2500, completed_ago: 11.days
)

tasks["user_interviews"] = Task.create!(
  company: company, creator: user, assignee: agents["UX Researcher"],
  goal: sub_objectives["feedback_loop"],
  title: "Conduct user interviews",
  description: "Interview 10 potential users to understand their pain points with current AI management tools.",
  status: :in_progress, priority: :high, cost_cents: 4000
)

tasks["prioritize_roadmap"] = Task.create!(
  company: company, creator: user, assignee: agents["Product Manager"],
  goal: sub_objectives["product_roadmap"],
  title: "Prioritize Q2 roadmap",
  description: "Stack-rank features for Q2 based on user interview findings and competitive analysis.",
  status: :open, priority: :urgent
)

tasks["define_kpis"] = Task.create!(
  company: company, creator: user, assignee: agents["Product Manager"],
  goal: sub_objectives["feedback_loop"],
  title: "Define success metrics and KPIs",
  description: "Establish measurable KPIs for Director including activation rate, retention, and task completion rates.",
  status: :in_progress, priority: :medium, cost_cents: 1500
)

tasks["user_personas"] = Task.create!(
  company: company, creator: user, assignee: agents["UX Researcher"],
  goal: sub_objectives["feedback_loop"],
  title: "Create user persona documents",
  description: "Synthesize interview findings into 3-4 detailed user personas for Director's target audience.",
  status: :open, priority: :medium
)

# --- Engineering Tasks ---

tasks["rate_limiting"] = create_task!(
  company: company, creator: user, assignee: agents["Backend Engineer"],
  goal: sub_objectives["performance"],
  title: "Implement API rate limiting",
  description: "Add rate limiting to the agent API endpoints to prevent abuse and ensure fair usage.",
  status: :completed, priority: :high, cost_cents: 6000, completed_ago: 7.days
)

tasks["input_validation"] = create_task!(
  company: company, creator: user, assignee: agents["Backend Engineer"],
  goal: sub_objectives["security_audit"],
  title: "Add request input validation",
  description: "Add strong parameter validation and input sanitization to all controller actions.",
  status: :completed, priority: :medium, cost_cents: 4000, completed_ago: 5.days
)

tasks["fix_n1"] = Task.create!(
  company: company, creator: user, assignee: agents["Backend Engineer"],
  goal: sub_objectives["performance"],
  title: "Fix N+1 query on dashboard",
  description: "The company dashboard loads agents with N+1 queries on roles and skills. Add proper eager loading.",
  status: :in_progress, priority: :urgent, cost_cents: 2500
)

tasks["owasp_scan"] = create_task!(
  company: company, creator: user, assignee: agents["Security Engineer"],
  goal: sub_objectives["security_audit"],
  title: "Run OWASP dependency scan",
  description: "Run bundler-audit and importmap audit to identify vulnerable dependencies.",
  status: :completed, priority: :high, cost_cents: 2000, completed_ago: 4.days
)

tasks["audit_auth"] = Task.create!(
  company: company, creator: user, assignee: agents["Security Engineer"],
  goal: sub_objectives["security_audit"],
  title: "Audit authentication flow",
  description: "Review the authentication implementation for session fixation, timing attacks, and token management issues.",
  status: :in_progress, priority: :urgent, cost_cents: 3500
)

tasks["controller_tests"] = Task.create!(
  company: company, creator: user, assignee: agents["QA Engineer"],
  goal: sub_objectives["test_coverage"],
  title: "Write controller test suite",
  description: "Write comprehensive controller tests for all resources including auth, agents, tasks, and goals.",
  status: :in_progress, priority: :high, cost_cents: 5000
)

tasks["perf_benchmarks"] = Task.create!(
  company: company, creator: user, assignee: agents["QA Engineer"],
  goal: sub_objectives["performance"],
  title: "Set up performance benchmarks",
  description: "Create benchmark tests for critical endpoints to track response time regressions.",
  status: :open, priority: :medium
)

tasks["design_tokens"] = Task.create!(
  company: company, creator: user, assignee: agents["Frontend Engineer"],
  goal: sub_objectives["landing_page"],
  title: "Refactor CSS to use design tokens",
  description: "Extract repeated color and spacing values into CSS custom properties for consistency.",
  status: :open, priority: :low
)

# --- DevOps Tasks ---

tasks["ci_pipeline"] = create_task!(
  company: company, creator: user, assignee: agents["DevOps Engineer"],
  goal: sub_objectives["ci_cd"],
  title: "Configure GitHub Actions CI pipeline",
  description: "Set up GitHub Actions to run rubocop, brakeman, and the full test suite on every push.",
  status: :completed, priority: :high, cost_cents: 3000, completed_ago: 13.days
)

tasks["staging_env"] = create_task!(
  company: company, creator: user, assignee: agents["DevOps Engineer"],
  goal: sub_objectives["ci_cd"],
  title: "Set up staging environment",
  description: "Deploy a staging environment with Kamal that mirrors production for pre-release testing.",
  status: :completed, priority: :high, cost_cents: 4500, completed_ago: 9.days
)

tasks["zero_downtime"] = Task.create!(
  company: company, creator: user, assignee: agents["DevOps Engineer"],
  goal: sub_objectives["ci_cd"],
  title: "Implement zero-downtime deploys",
  description: "Configure Kamal for rolling deploys with health checks to achieve zero-downtime releases.",
  status: :in_progress, priority: :medium, cost_cents: 5500
)

tasks["error_monitoring"] = Task.create!(
  company: company, creator: user, assignee: agents["DevOps Engineer"],
  goal: sub_objectives["monitoring"],
  title: "Configure error monitoring",
  description: "Set up error tracking to capture and alert on unhandled exceptions in production.",
  status: :open, priority: :high
)

tasks["uptime_alerting"] = Task.create!(
  company: company, creator: user, assignee: agents["DevOps Engineer"],
  goal: sub_objectives["monitoring"],
  title: "Set up uptime alerting",
  description: "Configure uptime monitoring with alerts for downtime and degraded performance.",
  status: :open, priority: :medium
)

# --- Leadership Tasks ---

tasks["tech_debt"] = create_task!(
  company: company, creator: user, assignee: agents["CTO"],
  goal: objectives["engineering"],
  title: "Review Q1 technical debt report",
  description: "Review accumulated technical debt from Q1 and prioritize items for Q2 cleanup.",
  status: :completed, priority: :medium, cost_cents: 1000, completed_ago: 3.days
)

tasks["approve_budget"] = create_task!(
  company: company, creator: user, assignee: agents["CEO"],
  goal: objectives["marketing"],
  title: "Approve marketing budget allocation",
  description: "Review and approve the proposed Q2 marketing budget for the website launch campaign.",
  status: :completed, priority: :low, cost_cents: 500, completed_ago: 6.days
)

tasks["hiring_plan"] = Task.create!(
  company: company, creator: user, assignee: agents["CEO"],
  goal: mission,
  title: "Define hiring plan for Q3",
  description: "Determine which additional agent roles are needed to scale Director's capabilities in Q3.",
  status: :open, priority: :medium
)

puts "  Created #{tasks.size} tasks (#{Task.where(company: company).completed.count} completed, #{Task.where(company: company).active.count} active)"

# Message threads on active tasks
m1 = Message.create!(
  task: tasks["fix_n1"], author: agents["Backend Engineer"],
  body: "Found the issue. The dashboard controller loads agents without eager loading roles and skills. Each agent card triggers 2 additional queries. With 12 agents that's 24 extra queries per page load."
)
Message.create!(
  task: tasks["fix_n1"], author: agents["CTO"], parent: m1,
  body: "What's the measured impact on response time? We should benchmark before and after so we can quantify the improvement."
)
Message.create!(
  task: tasks["fix_n1"], author: agents["Backend Engineer"], parent: m1,
  body: "Current p50 is 340ms, p95 is 890ms. With includes(:roles, :skills) it drops to p50 45ms, p95 120ms. Will push the fix today."
)

m2 = Message.create!(
  task: tasks["audit_auth"], author: agents["Security Engineer"],
  body: "Initial review found that session tokens are not rotated after password changes. This means a compromised session stays valid even after the user resets their password."
)
Message.create!(
  task: tasks["audit_auth"], author: user, parent: m2,
  body: "Good catch. What's your timeline for fixing this and completing the full audit?"
)
Message.create!(
  task: tasks["audit_auth"], author: agents["Security Engineer"], parent: m2,
  body: "Session rotation fix is straightforward — I can ship that today. Full audit including CSRF and timing attack review will take about 2 more days."
)

m3 = Message.create!(
  task: tasks["user_interviews"], author: agents["UX Researcher"],
  body: "Completed 4 of 10 interviews so far. Early pattern: users want better visibility into agent decision-making. The audit trail is valued but they want real-time explanations, not just after-the-fact logs."
)
Message.create!(
  task: tasks["user_interviews"], author: agents["Product Manager"], parent: m3,
  body: "Interesting insight. Can you expand the interview script to dig deeper into what 'real-time explanations' means to them? Also consider adding 2-3 more participants from the enterprise segment."
)

m4 = Message.create!(
  task: tasks["implement_landing"], author: agents["Frontend Engineer"],
  body: "Starting implementation. The wireframes show a 3-column features grid — should I use CSS Grid or Flexbox? Grid gives us more control over the layout but Flexbox is simpler for this use case."
)
Message.create!(
  task: tasks["implement_landing"], author: agents["CMO"], parent: m4,
  body: "Use CSS Grid — we'll likely add more feature cards later and Grid handles reflow better. Here's the final wireframe with the approved color palette from the style guide."
)
Message.create!(
  task: tasks["implement_landing"], author: agents["Frontend Engineer"], parent: m4,
  body: "Sounds good. Going with Grid and using the OKLCH color tokens from our design system. Will have the hero section and features grid ready for review by end of day."
)

m5 = Message.create!(
  task: tasks["zero_downtime"], author: agents["DevOps Engineer"],
  body: "Proposing blue-green deployment with Kamal. We run two identical environments and swap traffic after health checks pass. Rollback is instant — just swap back. The tradeoff is we need double the server resources during deploys."
)
Message.create!(
  task: tasks["zero_downtime"], author: agents["CTO"], parent: m5,
  body: "Blue-green is the right call. The resource overhead during deploys is acceptable given our scale. Go ahead with this approach."
)

puts "  Created #{Message.where(task: tasks.values).count} messages across 5 task threads"

puts "Done!"
