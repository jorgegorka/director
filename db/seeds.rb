# db/seeds.rb
#
# Seeds "Director AI" — a self-referential company that uses Director to improve itself.
# Run: bin/rails db:seed
# This REPLACES all existing data.

puts "Seeding Director AI..."

# Clean slate
Company.destroy_all
User.destroy_all
Session.destroy_all

# User & Company
user = User.create!(
  email_address: "admin@director.ai",
  password: "password123"
)

company = Company.create!(name: "Director AI")
# ↑ after_create callback auto-seeds 50 builtin skills

membership = Membership.create!(
  user: user,
  company: company,
  role: :owner
)

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
  skills_to_assign.each do |skill|
    agent.agent_skills.find_or_create_by!(skill: skill)
  end
end

puts "  Manually assigned skills to Security Engineer, SEO Specialist, Content Strategist"

puts "Done!"
