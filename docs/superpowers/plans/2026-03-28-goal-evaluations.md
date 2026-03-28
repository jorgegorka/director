# Goal Evaluations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn goals into active evaluation layer — when an agent completes a task, an AI evaluator judges pass/fail against the agent's assigned goal, with automatic retry on failure.

**Architecture:** New `GoalEvaluation` model records each evaluation attempt. A `GoalEvaluationService` makes a single-turn Claude API call to judge pass/fail. Triggered by an `after_commit` callback on Task completion when the assignee has a goal. Failed evaluations reopen the task, post feedback, and wake the agent. Max 3 retries before blocking.

**Tech Stack:** Rails 8, SQLite, Minitest + fixtures, Hotwire views, `net/http` for Claude API calls.

---

## File Structure

**New files:**
- `db/migrate/TIMESTAMP_add_goal_id_to_agents.rb` — FK on agents table
- `db/migrate/TIMESTAMP_create_goal_evaluations.rb` — new table
- `app/models/goal_evaluation.rb` — evaluation model
- `app/jobs/evaluate_goal_alignment_job.rb` — async job
- `app/services/goal_evaluation_service.rb` — orchestrates evaluation flow
- `app/services/ai_client.rb` — thin Claude API wrapper
- `test/models/goal_evaluation_test.rb` — model tests
- `test/services/goal_evaluation_service_test.rb` — service tests
- `test/services/ai_client_test.rb` — client tests
- `test/jobs/evaluate_goal_alignment_job_test.rb` — job tests
- `test/fixtures/goal_evaluations.yml` — fixtures

**Modified files:**
- `app/models/agent.rb` — add `belongs_to :goal`, validation
- `app/models/goal.rb` — add `has_many :agents`, `has_many :goal_evaluations`
- `app/models/task.rb` — add `after_commit :enqueue_goal_evaluation`
- `app/models/heartbeat_event.rb` — add `goal_evaluation_failed` trigger type
- `app/models/audit_event.rb` — add `goal_evaluation_exhausted` to GOVERNANCE_ACTIONS
- `app/controllers/agents_controller.rb` — permit `goal_id`, load goals for form
- `app/views/agents/_form.html.erb` — goal select dropdown
- `app/views/agents/show.html.erb` — goal section with eval stats
- `app/views/tasks/show.html.erb` — evaluations section
- `app/views/goals/show.html.erb` — evaluation stats
- `test/fixtures/agents.yml` — add goal references
- `test/fixtures/tasks.yml` — add eval-related task
- `test/models/agent_test.rb` — goal association tests
- `test/models/task_test.rb` — evaluation trigger tests
- `test/controllers/agents_controller_test.rb` — goal_id in form

---

### Task 1: Migration — Add goal_id to agents

**Files:**
- Create: `db/migrate/TIMESTAMP_add_goal_id_to_agents.rb`

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration AddGoalIdToAgents goal:references
```

- [ ] **Step 2: Edit the migration to make FK optional**

The generated migration will have `null: false` — we need it optional since not all agents have goals.

```ruby
class AddGoalIdToAgents < ActiveRecord::Migration[8.0]
  def change
    add_reference :agents, :goal, null: true, foreign_key: true
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
bin/rails db:migrate
```

Expected: Migration runs successfully, `schema.rb` shows `goal_id` on agents table.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_add_goal_id_to_agents.rb db/schema.rb
git commit -m "Add goal_id FK to agents table"
```

---

### Task 2: Migration — Create goal_evaluations table

**Files:**
- Create: `db/migrate/TIMESTAMP_create_goal_evaluations.rb`

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration CreateGoalEvaluations
```

- [ ] **Step 2: Write the migration**

```ruby
class CreateGoalEvaluations < ActiveRecord::Migration[8.0]
  def change
    create_table :goal_evaluations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true
      t.references :goal, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: true
      t.integer :result, null: false
      t.text :feedback, null: false
      t.integer :attempt_number, null: false
      t.integer :cost_cents

      t.timestamps
    end

    add_index :goal_evaluations, [ :task_id, :attempt_number ], unique: true
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
bin/rails db:migrate
```

Expected: Migration runs successfully, `schema.rb` shows `goal_evaluations` table.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_create_goal_evaluations.rb db/schema.rb
git commit -m "Create goal_evaluations table"
```

---

### Task 3: GoalEvaluation model + tests

**Files:**
- Create: `app/models/goal_evaluation.rb`
- Create: `test/models/goal_evaluation_test.rb`
- Create: `test/fixtures/goal_evaluations.yml`
- Modify: `app/models/goal.rb:5-6` — add associations
- Modify: `app/models/task.rb:1-4` — add association
- Modify: `test/fixtures/agents.yml` — add goal reference to claude_agent
- Modify: `test/fixtures/tasks.yml` — add eval-ready task

- [ ] **Step 1: Update fixtures to support goal evaluations**

In `test/fixtures/agents.yml`, add `goal: acme_objective_one` to the `claude_agent` fixture:

```yaml
claude_agent:
  name: Claude Assistant
  company: acme
  adapter_type: 2  # claude_local
  status: 0        # idle
  adapter_config:
    model: claude-sonnet-4-20250514
  description: "Primary AI development assistant"
  api_token: "test_token_claude_agent_abc1"
  budget_cents: 50000
  budget_period_start: <%= Date.current.beginning_of_month.to_fs(:db) %>
  goal: acme_objective_one
```

In `test/fixtures/tasks.yml`, add a task that's ready for evaluation (completed, assigned to agent with goal):

```yaml
eval_ready_task:
  title: Implement search feature
  description: "Add full-text search to the product catalog"
  company: acme
  creator: one
  assignee: claude_agent
  status: 3  # completed
  priority: 1  # medium
  goal: acme_objective_one
  cost_cents: 1000
  completed_at: <%= 1.hour.ago.to_fs(:db) %>
```

Create `test/fixtures/goal_evaluations.yml`:

```yaml
passing_eval:
  company: acme
  task: eval_ready_task
  goal: acme_objective_one
  agent: claude_agent
  result: 0  # pass
  feedback: "Task directly advances the MVP launch objective by adding a core feature."
  attempt_number: 1
  cost_cents: 50

failed_eval:
  company: acme
  task: completed_task
  goal: acme_sub_objective
  agent: claude_agent
  result: 1  # fail
  feedback: "CI pipeline setup does not directly advance the authentication module completion."
  attempt_number: 1
  cost_cents: 45
```

- [ ] **Step 2: Write the failing model test**

Create `test/models/goal_evaluation_test.rb`:

```ruby
require "test_helper"

class GoalEvaluationTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @agent = agents(:claude_agent)
    @goal = goals(:acme_objective_one)
    @task = tasks(:eval_ready_task)
    @evaluation = goal_evaluations(:passing_eval)
  end

  # --- Associations ---

  test "belongs to company" do
    assert_equal @company, @evaluation.company
  end

  test "belongs to task" do
    assert_equal @task, @evaluation.task
  end

  test "belongs to goal" do
    assert_equal @goal, @evaluation.goal
  end

  test "belongs to agent" do
    assert_equal @agent, @evaluation.agent
  end

  # --- Validations ---

  test "requires result" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, agent: @agent,
      feedback: "Good work", attempt_number: 1
    )
    assert_not evaluation.valid?
    assert_includes evaluation.errors[:result], "can't be blank"
  end

  test "requires feedback" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, agent: @agent,
      result: :pass, attempt_number: 1
    )
    assert_not evaluation.valid?
    assert_includes evaluation.errors[:feedback], "can't be blank"
  end

  test "requires attempt_number" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, agent: @agent,
      result: :pass, feedback: "Good"
    )
    assert_not evaluation.valid?
    assert_includes evaluation.errors[:attempt_number], "can't be blank"
  end

  test "attempt_number must be positive integer" do
    evaluation = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, agent: @agent,
      result: :pass, feedback: "Good", attempt_number: 0
    )
    assert_not evaluation.valid?
  end

  test "attempt_number must be unique per task" do
    duplicate = GoalEvaluation.new(
      company: @company, task: @task, goal: @goal, agent: @agent,
      result: :fail, feedback: "Not aligned", attempt_number: 1
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:attempt_number], "has already been taken"
  end

  test "cost_cents must be non-negative if present" do
    @evaluation.cost_cents = -1
    assert_not @evaluation.valid?
  end

  test "cost_cents can be nil" do
    @evaluation.cost_cents = nil
    assert @evaluation.valid?
  end

  # --- Enums ---

  test "result enum has pass and fail" do
    assert GoalEvaluation.new(result: :pass).pass?
    assert GoalEvaluation.new(result: :fail).fail?
  end

  # --- Scopes ---

  test "passed scope returns only passing evaluations" do
    results = GoalEvaluation.passed
    assert results.all?(&:pass?)
  end

  test "failed scope returns only failing evaluations" do
    results = GoalEvaluation.failed
    assert results.all?(&:fail?)
  end

  # --- MAX_ATTEMPTS constant ---

  test "MAX_ATTEMPTS is 3" do
    assert_equal 3, GoalEvaluation::MAX_ATTEMPTS
  end

  # --- Destruction ---

  test "goal evaluation is destroyed when task is destroyed" do
    assert_difference "GoalEvaluation.count", -1 do
      @task.destroy
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

```bash
bin/rails test test/models/goal_evaluation_test.rb
```

Expected: Errors — `GoalEvaluation` class not defined.

- [ ] **Step 4: Create the GoalEvaluation model**

Create `app/models/goal_evaluation.rb`:

```ruby
class GoalEvaluation < ApplicationRecord
  include Tenantable

  MAX_ATTEMPTS = 3

  belongs_to :task
  belongs_to :goal
  belongs_to :agent

  enum :result, { pass: 0, fail: 1 }

  validates :result, presence: true
  validates :feedback, presence: true
  validates :attempt_number, presence: true,
                             numericality: { only_integer: true, greater_than: 0 },
                             uniqueness: { scope: :task_id }
  validates :cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :passed, -> { where(result: :pass) }
  scope :failed, -> { where(result: :fail) }
end
```

- [ ] **Step 5: Add associations to Goal and Task models**

In `app/models/goal.rb`, after line 6 (`has_many :tasks, dependent: :nullify`), add:

```ruby
  has_many :agents
  has_many :goal_evaluations, dependent: :destroy
```

In `app/models/task.rb`, after line 15 (`has_many :agent_runs, dependent: :nullify`), add:

```ruby
  has_many :goal_evaluations, dependent: :destroy
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bin/rails test test/models/goal_evaluation_test.rb
```

Expected: All tests pass.

- [ ] **Step 7: Run full test suite to check for regressions**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 8: Commit**

```bash
git add app/models/goal_evaluation.rb app/models/goal.rb app/models/task.rb \
  test/models/goal_evaluation_test.rb test/fixtures/goal_evaluations.yml \
  test/fixtures/agents.yml test/fixtures/tasks.yml
git commit -m "Add GoalEvaluation model with validations and associations"
```

---

### Task 4: Agent goal association + tests

**Files:**
- Modify: `app/models/agent.rb:1-10` — add `belongs_to :goal` + validation
- Modify: `test/models/agent_test.rb` — add goal association tests

- [ ] **Step 1: Write the failing tests**

Add these tests to the bottom of `test/models/agent_test.rb` (before the final `end`):

```ruby
  # --- Goal association ---

  test "agent can have an optional goal" do
    agent = agents(:http_agent)
    assert_nil agent.goal
    assert agent.valid?
  end

  test "agent can be assigned a goal" do
    agent = agents(:claude_agent)
    assert_equal goals(:acme_objective_one), agent.goal
  end

  test "goal must belong to same company" do
    agent = agents(:claude_agent)
    agent.goal = goals(:widgets_mission)
    assert_not agent.valid?
    assert_includes agent.errors[:goal], "must belong to the same company"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/agent_test.rb -n "/goal/"
```

Expected: Failures — agent doesn't have `goal` association yet.

- [ ] **Step 3: Add goal association to Agent model**

In `app/models/agent.rb`, after line 17 (`has_many :documents, through: :agent_documents`), add:

```ruby
  belongs_to :goal, optional: true
```

In the private section, after the `validate_adapter_config_schema` method (around line 219), add:

```ruby
  def goal_belongs_to_same_company
    if goal.present? && goal.company_id != company_id
      errors.add(:goal, "must belong to the same company")
    end
  end
```

After line 28 (`validate :validate_adapter_config_schema`), add:

```ruby
  validate :goal_belongs_to_same_company
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/models/agent_test.rb -n "/goal/"
```

Expected: All 3 goal tests pass.

- [ ] **Step 5: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 6: Commit**

```bash
git add app/models/agent.rb test/models/agent_test.rb
git commit -m "Add goal association to Agent with company validation"
```

---

### Task 5: Add goal_evaluation_failed trigger type to HeartbeatEvent

**Files:**
- Modify: `app/models/heartbeat_event.rb:6` — extend enum

- [ ] **Step 1: Update the HeartbeatEvent trigger_type enum**

In `app/models/heartbeat_event.rb`, change line 6 from:

```ruby
  enum :trigger_type, { scheduled: 0, task_assigned: 1, mention: 2, hook_triggered: 3, review_validation: 4 }
```

to:

```ruby
  enum :trigger_type, { scheduled: 0, task_assigned: 1, mention: 2, hook_triggered: 3, review_validation: 4, goal_evaluation_failed: 5 }
```

- [ ] **Step 2: Add goal_evaluation_exhausted to AuditEvent GOVERNANCE_ACTIONS**

In `app/models/audit_event.rb`, add `goal_evaluation_exhausted` to the `GOVERNANCE_ACTIONS` array (after `validation_feedback_received`):

```ruby
  GOVERNANCE_ACTIONS = %w[
    gate_approval
    gate_rejection
    gate_blocked
    emergency_stop
    emergency_resume
    agent_paused
    agent_resumed
    agent_terminated
    config_rollback
    cost_recorded
    hook_executed
    validation_feedback_received
    goal_evaluation_exhausted
  ].freeze
```

- [ ] **Step 3: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 4: Commit**

```bash
git add app/models/heartbeat_event.rb app/models/audit_event.rb
git commit -m "Add goal_evaluation_failed trigger type and governance action"
```

---

### Task 6: AiClient service + tests

**Files:**
- Create: `app/services/ai_client.rb`
- Create: `test/services/ai_client_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/ai_client_test.rb`:

```ruby
require "test_helper"

class AiClientTest < ActiveSupport::TestCase
  test "chat returns parsed JSON response" do
    mock_response = {
      "content" => [ { "type" => "text", "text" => '{"result":"pass","feedback":"Good work"}' } ],
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })

    result = AiClient.chat(
      system: "You are an evaluator.",
      prompt: "Evaluate this task."
    )

    assert_equal "pass", result[:parsed]["result"]
    assert_equal "Good work", result[:parsed]["feedback"]
    assert_equal 100, result[:usage]["input_tokens"]
    assert_equal 50, result[:usage]["output_tokens"]
  end

  test "chat raises on API error" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 500, body: '{"error":{"message":"Internal error"}}')

    assert_raises(AiClient::ApiError) do
      AiClient.chat(system: "test", prompt: "test")
    end
  end

  test "chat raises on invalid JSON in response text" do
    mock_response = {
      "content" => [ { "type" => "text", "text" => "not valid json" } ],
      "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })

    assert_raises(AiClient::ParseError) do
      AiClient.chat(system: "test", prompt: "test")
    end
  end

  test "estimate_cost_cents calculates from usage" do
    usage = { "input_tokens" => 1000, "output_tokens" => 500 }
    cost = AiClient.estimate_cost_cents(usage)
    assert_kind_of Integer, cost
    assert cost >= 0
  end
end
```

- [ ] **Step 2: Check if webmock is available**

```bash
grep webmock Gemfile
```

If webmock is not present, add it to the test group in `Gemfile`:

```ruby
group :test do
  gem "webmock"
end
```

Then run:

```bash
bundle install
```

And add to `test/test_helper.rb` (after the existing requires):

```ruby
require "webmock/minitest"
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bin/rails test test/services/ai_client_test.rb
```

Expected: Errors — `AiClient` class not defined.

- [ ] **Step 4: Create the AiClient service**

Create `app/services/ai_client.rb`:

```ruby
class AiClient
  API_URL = "https://api.anthropic.com/v1/messages".freeze
  MODEL = "claude-sonnet-4-20250514".freeze
  MAX_TOKENS = 1024

  # Pricing per million tokens (Sonnet 4)
  INPUT_COST_PER_MILLION = 3.0
  OUTPUT_COST_PER_MILLION = 15.0

  class ApiError < StandardError; end
  class ParseError < StandardError; end

  def self.chat(system:, prompt:, model: MODEL, max_tokens: MAX_TOKENS)
    new.chat(system: system, prompt: prompt, model: model, max_tokens: max_tokens)
  end

  def self.estimate_cost_cents(usage)
    input_cost = (usage["input_tokens"].to_f / 1_000_000) * INPUT_COST_PER_MILLION
    output_cost = (usage["output_tokens"].to_f / 1_000_000) * OUTPUT_COST_PER_MILLION
    ((input_cost + output_cost) * 100).ceil
  end

  def chat(system:, prompt:, model: MODEL, max_tokens: MAX_TOKENS)
    body = {
      model: model,
      max_tokens: max_tokens,
      system: system,
      messages: [ { role: "user", content: prompt } ]
    }

    response = post_request(body)
    parsed_body = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      error_msg = parsed_body.dig("error", "message") || "API request failed with status #{response.code}"
      raise ApiError, error_msg
    end

    text = parsed_body.dig("content", 0, "text")
    parsed_text = parse_json_response(text)

    {
      parsed: parsed_text,
      usage: parsed_body["usage"],
      raw_text: text
    }
  end

  private

  def post_request(body)
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"
    request.body = body.to_json

    http.request(request)
  end

  def api_key
    Rails.application.credentials.dig(:anthropic, :api_key) ||
      ENV["ANTHROPIC_API_KEY"] ||
      raise(ApiError, "No Anthropic API key configured. Set credentials.anthropic.api_key or ANTHROPIC_API_KEY env var.")
  end

  def parse_json_response(text)
    JSON.parse(text)
  rescue JSON::ParserError => e
    raise ParseError, "Failed to parse AI response as JSON: #{e.message}"
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/services/ai_client_test.rb
```

Expected: All 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/services/ai_client.rb test/services/ai_client_test.rb
# If webmock was added:
# git add Gemfile Gemfile.lock test/test_helper.rb
git commit -m "Add AiClient service for single-turn Claude API calls"
```

---

### Task 7: GoalEvaluationService + tests

**Files:**
- Create: `app/services/goal_evaluation_service.rb`
- Create: `test/services/goal_evaluation_service_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/goal_evaluation_service_test.rb`:

```ruby
require "test_helper"

class GoalEvaluationServiceTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @agent = agents(:claude_agent)
    @goal = goals(:acme_objective_one)

    # Create a completed task with an agent that has a goal
    @task = Task.create!(
      title: "Build search feature",
      description: "Add full-text search",
      company: @company,
      assignee: @agent,
      goal: @goal,
      status: :open
    )
    @task.update_columns(status: 3, completed_at: Time.current)
    @task.reload

    # Add a work output message
    Message.create!(task: @task, author: @agent, body: "I implemented full-text search using pg_search.")
  end

  # --- Pass flow ---

  test "creates a passing GoalEvaluation when AI returns pass" do
    stub_ai_response(result: "pass", feedback: "Search feature directly advances MVP launch.")

    assert_difference "GoalEvaluation.count", 1 do
      GoalEvaluationService.call(@task)
    end

    evaluation = GoalEvaluation.last
    assert evaluation.pass?
    assert_equal "Search feature directly advances MVP launch.", evaluation.feedback
    assert_equal 1, evaluation.attempt_number
    assert_equal @task.id, evaluation.task_id
    assert_equal @goal.id, evaluation.goal_id
    assert_equal @agent.id, evaluation.agent_id
    assert_equal @company.id, evaluation.company_id
  end

  test "task stays completed on pass" do
    stub_ai_response(result: "pass", feedback: "Good.")

    GoalEvaluationService.call(@task)
    @task.reload

    assert @task.completed?
  end

  test "does not wake agent on pass" do
    stub_ai_response(result: "pass", feedback: "Good.")

    assert_no_difference "HeartbeatEvent.count" do
      GoalEvaluationService.call(@task)
    end
  end

  # --- Fail flow ---

  test "creates a failing GoalEvaluation when AI returns fail" do
    stub_ai_response(result: "fail", feedback: "This doesn't advance the goal.")

    assert_difference "GoalEvaluation.count", 1 do
      GoalEvaluationService.call(@task)
    end

    evaluation = GoalEvaluation.last
    assert evaluation.fail?
    assert_equal "This doesn't advance the goal.", evaluation.feedback
  end

  test "reopens task to in_progress on fail" do
    stub_ai_response(result: "fail", feedback: "Not aligned.")

    GoalEvaluationService.call(@task)
    @task.reload

    assert @task.in_progress?
    assert_nil @task.completed_at
  end

  test "posts feedback message on task on fail" do
    stub_ai_response(result: "fail", feedback: "Needs more alignment.")

    assert_difference "Message.count", 1 do
      GoalEvaluationService.call(@task)
    end

    message = @task.messages.order(:created_at).last
    assert_includes message.body, "Needs more alignment."
    assert_includes message.body, "Goal Evaluation"
  end

  test "wakes agent with goal_evaluation_failed trigger on fail" do
    stub_ai_response(result: "fail", feedback: "Not aligned.")

    assert_difference "HeartbeatEvent.count", 1 do
      GoalEvaluationService.call(@task)
    end

    event = HeartbeatEvent.order(:created_at).last
    assert event.goal_evaluation_failed?
    assert_equal @agent.id, event.agent_id
  end

  # --- Retry exhaustion ---

  test "blocks task after MAX_ATTEMPTS failed evaluations" do
    # Create 2 prior failed evaluations
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, agent: @agent,
      result: :fail, feedback: "Attempt 1", attempt_number: 1, cost_cents: 50)
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, agent: @agent,
      result: :fail, feedback: "Attempt 2", attempt_number: 2, cost_cents: 50)

    stub_ai_response(result: "fail", feedback: "Still not aligned.")

    GoalEvaluationService.call(@task)
    @task.reload

    assert @task.blocked?
  end

  test "records audit event on retry exhaustion" do
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, agent: @agent,
      result: :fail, feedback: "Attempt 1", attempt_number: 1, cost_cents: 50)
    GoalEvaluation.create!(company: @company, task: @task, goal: @goal, agent: @agent,
      result: :fail, feedback: "Attempt 2", attempt_number: 2, cost_cents: 50)

    stub_ai_response(result: "fail", feedback: "Still not aligned.")

    assert_difference "AuditEvent.count" do
      GoalEvaluationService.call(@task)
    end

    audit = AuditEvent.where(action: "goal_evaluation_exhausted").last
    assert_equal @task, audit.auditable
  end

  test "skips evaluation when max attempts already reached" do
    3.times do |i|
      GoalEvaluation.create!(company: @company, task: @task, goal: @goal, agent: @agent,
        result: :fail, feedback: "Attempt #{i + 1}", attempt_number: i + 1, cost_cents: 50)
    end

    assert_no_difference "GoalEvaluation.count" do
      GoalEvaluationService.call(@task)
    end
  end

  # --- Edge cases ---

  test "skips when task assignee has no goal" do
    @agent.update_columns(goal_id: nil)
    @task.reload

    assert_no_difference "GoalEvaluation.count" do
      GoalEvaluationService.call(@task)
    end
  end

  test "skips when task is not completed" do
    @task.update_columns(status: 1)  # in_progress
    @task.reload

    assert_no_difference "GoalEvaluation.count" do
      GoalEvaluationService.call(@task)
    end
  end

  # --- Budget charging ---

  test "adds evaluation cost to task cost_cents" do
    stub_ai_response(result: "pass", feedback: "Good.", input_tokens: 500, output_tokens: 100)

    GoalEvaluationService.call(@task)
    @task.reload

    assert @task.cost_cents > 1000  # original 1000 + eval cost
  end

  private

  def stub_ai_response(result:, feedback:, input_tokens: 100, output_tokens: 50)
    response_text = { result: result, feedback: feedback }.to_json
    mock_response = {
      "content" => [ { "type" => "text", "text" => response_text } ],
      "usage" => { "input_tokens" => input_tokens, "output_tokens" => output_tokens }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/services/goal_evaluation_service_test.rb
```

Expected: Errors — `GoalEvaluationService` not defined.

- [ ] **Step 3: Create the GoalEvaluationService**

Create `app/services/goal_evaluation_service.rb`:

```ruby
class GoalEvaluationService
  attr_reader :task

  def initialize(task)
    @task = task
  end

  def self.call(task)
    new(task).call
  end

  def call
    return unless task.completed?
    return unless agent&.goal.present?
    return if attempts_exhausted?

    result = evaluate
    evaluation = record_evaluation(result)

    if evaluation.fail?
      if evaluation.attempt_number >= GoalEvaluation::MAX_ATTEMPTS
        block_task(evaluation)
      else
        reopen_task(evaluation)
      end
    end

    evaluation
  end

  private

  def agent
    @agent ||= task.assignee
  end

  def goal
    @goal ||= agent.goal
  end

  def attempt_number
    @attempt_number ||= task.goal_evaluations.count + 1
  end

  def attempts_exhausted?
    task.goal_evaluations.count >= GoalEvaluation::MAX_ATTEMPTS
  end

  def evaluate
    AiClient.chat(
      system: system_prompt,
      prompt: evaluation_prompt
    )
  end

  def system_prompt
    "You are evaluating whether a completed task advances a company goal. " \
    "Respond ONLY with valid JSON: {\"result\": \"pass\" or \"fail\", \"feedback\": \"2-3 sentence explanation\"}"
  end

  def evaluation_prompt
    parts = []
    parts << "## Goal Hierarchy"
    goal.ancestry_chain.each_with_index do |g, i|
      indent = "  " * i
      label = g.root? ? "Mission" : "Objective"
      parts << "#{indent}#{label}: #{g.title}"
      parts << "#{indent}  #{g.description}" if g.description.present?
    end

    parts << ""
    parts << "## Completed Task"
    parts << "Title: #{task.title}"
    parts << "Description: #{task.description}" if task.description.present?

    work_output = task.messages.order(:created_at).pluck(:body)
    if work_output.any?
      parts << ""
      parts << "## Work Output"
      work_output.each { |body| parts << body }
    end

    parts << ""
    parts << "Evaluate whether this task's output meaningfully advances the stated goal."

    parts.join("\n")
  end

  def record_evaluation(result)
    cost_cents = AiClient.estimate_cost_cents(result[:usage])

    evaluation = GoalEvaluation.create!(
      company_id: task.company_id,
      task: task,
      goal: goal,
      agent: agent,
      result: result[:parsed]["result"],
      feedback: result[:parsed]["feedback"],
      attempt_number: attempt_number,
      cost_cents: cost_cents
    )

    charge_cost(cost_cents)
    evaluation
  end

  def charge_cost(cost_cents)
    return unless cost_cents&.positive?
    new_cost = (task.cost_cents || 0) + cost_cents
    task.update_column(:cost_cents, new_cost)
  end

  def reopen_task(evaluation)
    post_feedback_message(evaluation)
    task.update!(status: :in_progress)
    wake_agent(evaluation)
  end

  def block_task(evaluation)
    post_feedback_message(evaluation)
    task.update!(status: :blocked)
    record_exhaustion_audit(evaluation)
  end

  def post_feedback_message(evaluation)
    Message.create!(
      task: task,
      author: agent,
      body: build_feedback_body(evaluation)
    )
  end

  def build_feedback_body(evaluation)
    status = evaluation.pass? ? "PASS" : "FAIL"
    parts = []
    parts << "## Goal Evaluation — #{status} (Attempt #{evaluation.attempt_number}/#{GoalEvaluation::MAX_ATTEMPTS})"
    parts << ""
    parts << "**Goal:** #{goal.title}"
    parts << ""
    parts << evaluation.feedback

    if evaluation.fail? && evaluation.attempt_number >= GoalEvaluation::MAX_ATTEMPTS
      parts << ""
      parts << "_Evaluation attempts exhausted. Task has been blocked for review._"
    end

    parts.join("\n")
  end

  def wake_agent(evaluation)
    return if agent.terminated?

    WakeAgentService.call(
      agent: agent,
      trigger_type: :goal_evaluation_failed,
      trigger_source: "GoalEvaluation##{evaluation.id}",
      context: {
        task_id: task.id,
        task_title: task.title,
        goal_id: goal.id,
        goal_title: goal.title,
        attempt_number: evaluation.attempt_number,
        feedback: evaluation.feedback
      }
    )
  end

  def record_exhaustion_audit(evaluation)
    task.record_audit_event!(
      actor: agent,
      action: "goal_evaluation_exhausted",
      company: task.company,
      metadata: {
        goal_id: goal.id,
        goal_title: goal.title,
        attempt_number: evaluation.attempt_number,
        feedback: evaluation.feedback
      }
    )
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/services/goal_evaluation_service_test.rb
```

Expected: All tests pass.

- [ ] **Step 5: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 6: Commit**

```bash
git add app/services/goal_evaluation_service.rb test/services/goal_evaluation_service_test.rb
git commit -m "Add GoalEvaluationService with pass/fail flow and retry logic"
```

---

### Task 8: EvaluateGoalAlignmentJob + tests

**Files:**
- Create: `app/jobs/evaluate_goal_alignment_job.rb`
- Create: `test/jobs/evaluate_goal_alignment_job_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/jobs/evaluate_goal_alignment_job_test.rb`:

```ruby
require "test_helper"

class EvaluateGoalAlignmentJobTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @agent = agents(:claude_agent)
    @goal = goals(:acme_objective_one)
  end

  test "skips when task not found" do
    assert_nothing_raised do
      EvaluateGoalAlignmentJob.perform_now(999999)
    end
  end

  test "skips when task is not completed" do
    task = tasks(:design_homepage)  # in_progress

    assert_no_difference "GoalEvaluation.count" do
      EvaluateGoalAlignmentJob.perform_now(task.id)
    end
  end

  test "skips when assignee has no goal" do
    task = Task.create!(
      title: "No goal task",
      company: @company,
      assignee: agents(:http_agent),  # no goal assigned
      status: :open
    )
    task.update_columns(status: 3, completed_at: Time.current)

    assert_no_difference "GoalEvaluation.count" do
      EvaluateGoalAlignmentJob.perform_now(task.id)
    end
  end

  test "calls GoalEvaluationService for eligible task" do
    task = Task.create!(
      title: "Eval job test",
      company: @company,
      assignee: @agent,
      goal: @goal,
      status: :open
    )
    task.update_columns(status: 3, completed_at: Time.current)
    task.reload

    stub_ai_pass_response

    assert_difference "GoalEvaluation.count", 1 do
      EvaluateGoalAlignmentJob.perform_now(task.id)
    end
  end

  test "job is enqueued to default queue" do
    assert_equal "default", EvaluateGoalAlignmentJob.new.queue_name
  end

  private

  def stub_ai_pass_response
    response_text = { result: "pass", feedback: "Good work." }.to_json
    mock_response = {
      "content" => [ { "type" => "text", "text" => response_text } ],
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/jobs/evaluate_goal_alignment_job_test.rb
```

Expected: Errors — `EvaluateGoalAlignmentJob` not defined.

- [ ] **Step 3: Create the job**

Create `app/jobs/evaluate_goal_alignment_job.rb`:

```ruby
class EvaluateGoalAlignmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return unless task
    return unless task.completed?
    return unless task.assignee&.goal.present?

    GoalEvaluationService.call(task)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/jobs/evaluate_goal_alignment_job_test.rb
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/jobs/evaluate_goal_alignment_job.rb test/jobs/evaluate_goal_alignment_job_test.rb
git commit -m "Add EvaluateGoalAlignmentJob for async goal evaluation"
```

---

### Task 9: Task completion callback to trigger evaluation

**Files:**
- Modify: `app/models/task.rb:37-38` — add callback
- Modify: `test/models/task_test.rb` — add trigger tests

- [ ] **Step 1: Write the failing tests**

Add to the bottom of `test/models/task_test.rb` (before the final `end`):

```ruby
  # --- Goal evaluation trigger ---

  test "enqueues goal evaluation job when task completes and assignee has goal" do
    agent = agents(:claude_agent)  # has goal
    task = Task.create!(title: "Eval trigger test", company: companies(:acme), assignee: agent, status: :open)

    assert_enqueued_with(job: EvaluateGoalAlignmentJob) do
      task.update!(status: :completed)
    end
  end

  test "does not enqueue goal evaluation when assignee has no goal" do
    agent = agents(:http_agent)  # no goal
    task = Task.create!(title: "No goal trigger test", company: companies(:acme), assignee: agent, status: :open)

    assert_no_enqueued_jobs(only: EvaluateGoalAlignmentJob) do
      task.update!(status: :completed)
    end
  end

  test "does not enqueue goal evaluation when task is not completed" do
    agent = agents(:claude_agent)
    task = Task.create!(title: "Not completed test", company: companies(:acme), assignee: agent, status: :open)

    assert_no_enqueued_jobs(only: EvaluateGoalAlignmentJob) do
      task.update!(status: :in_progress)
    end
  end

  test "does not enqueue goal evaluation when task has no assignee" do
    task = Task.create!(title: "Unassigned test", company: companies(:acme), status: :open)

    assert_no_enqueued_jobs(only: EvaluateGoalAlignmentJob) do
      task.update!(status: :completed)
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/task_test.rb -n "/goal evaluation/"
```

Expected: Failures — no `enqueue_goal_evaluation` callback.

- [ ] **Step 3: Add the callback to Task model**

In `app/models/task.rb`, after line 38 (`after_commit :enqueue_validation_feedback, on: [ :create, :update ]`), add:

```ruby
  after_commit :enqueue_goal_evaluation, on: [ :create, :update ]
```

In the private section (before `def broadcast_kanban_update`), add:

```ruby
  def enqueue_goal_evaluation
    return unless saved_change_to_status?
    return unless completed?
    return unless assignee&.goal.present?

    EvaluateGoalAlignmentJob.perform_later(id)
  end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/models/task_test.rb -n "/goal evaluation/"
```

Expected: All 4 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions. Note: Some existing tests that complete tasks with an agent that now has a goal may enqueue the job — this is expected and should not cause failures since `perform_later` is non-blocking.

- [ ] **Step 6: Commit**

```bash
git add app/models/task.rb test/models/task_test.rb
git commit -m "Trigger goal evaluation on task completion when assignee has goal"
```

---

### Task 10: Agent form — goal select dropdown

**Files:**
- Modify: `app/controllers/agents_controller.rb:152-153` — permit `goal_id`
- Modify: `app/views/agents/_form.html.erb:18-19` — add goal dropdown
- Modify: `test/controllers/agents_controller_test.rb` — test goal_id form

- [ ] **Step 1: Write the failing controller test**

Add to `test/controllers/agents_controller_test.rb` (before the final `end`):

```ruby
  # --- Goal assignment ---

  test "create assigns goal to agent" do
    goal = goals(:acme_objective_one)

    assert_difference "Agent.count", 1 do
      post agents_path, params: { agent: {
        name: "Goal Agent",
        adapter_type: "http",
        adapter_config: { url: "https://example.com/agent" },
        goal_id: goal.id
      } }
    end

    agent = Agent.last
    assert_equal goal, agent.goal
  end

  test "update changes agent goal" do
    goal = goals(:acme_objective_two)

    patch agent_path(@agent), params: { agent: {
      name: @agent.name,
      adapter_type: @agent.adapter_type,
      adapter_config: @agent.adapter_config,
      goal_id: goal.id
    } }

    @agent.reload
    assert_equal goal, @agent.goal
  end

  test "update clears agent goal" do
    patch agent_path(@agent), params: { agent: {
      name: @agent.name,
      adapter_type: @agent.adapter_type,
      adapter_config: @agent.adapter_config,
      goal_id: ""
    } }

    @agent.reload
    assert_nil @agent.goal
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/agents_controller_test.rb -n "/goal/"
```

Expected: Failures — `goal_id` not permitted.

- [ ] **Step 3: Permit goal_id in agent_params**

In `app/controllers/agents_controller.rb`, change line 153 from:

```ruby
    permitted = params.require(:agent).permit(:name, :description, :adapter_type, :heartbeat_enabled, :heartbeat_interval, :budget_dollars)
```

to:

```ruby
    permitted = params.require(:agent).permit(:name, :description, :adapter_type, :heartbeat_enabled, :heartbeat_interval, :budget_dollars, :goal_id)
```

- [ ] **Step 4: Add goal dropdown to agent form**

In `app/views/agents/_form.html.erb`, after the description field (after line 18, before the adapter type field), add:

```erb
  <div class="form__field">
    <%= f.label :goal_id, "Goal" %>
    <%= f.select :goal_id,
          options_for_goal_select,
          { include_blank: "No goal" },
          { class: "form__select" } %>
    <p class="form__hint">Assign a goal to evaluate this agent's completed tasks against.</p>
  </div>
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/controllers/agents_controller_test.rb -n "/goal/"
```

Expected: All 3 tests pass.

- [ ] **Step 6: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/agents_controller.rb app/views/agents/_form.html.erb \
  test/controllers/agents_controller_test.rb
git commit -m "Add goal select dropdown to agent form"
```

---

### Task 11: Agent show page — Goal section with eval stats

**Files:**
- Modify: `app/controllers/agents_controller.rb:9-14` — load evaluation data
- Modify: `app/views/agents/show.html.erb:165` — add goal card to sidebar

- [ ] **Step 1: Load evaluation data in controller**

In `app/controllers/agents_controller.rb`, in the `show` action, after line 14 (`@agent_document_links = ...`), add:

```ruby
    if @agent.goal.present?
      @goal_evaluations = @agent.goal_evaluations.order(created_at: :desc).limit(5)
      @eval_total = @agent.goal_evaluations.count
      @eval_pass_count = @agent.goal_evaluations.passed.count
    end
```

Note: Also add `has_many :goal_evaluations` to Agent model. In `app/models/agent.rb`, after `has_many :agent_runs, dependent: :destroy` (line 14), add:

```ruby
  has_many :goal_evaluations, dependent: :destroy
```

- [ ] **Step 2: Add goal card to agent show sidebar**

In `app/views/agents/show.html.erb`, after the Configuration card closing `</div>` (line 188) and before the Budget card opening `<div>` (line 191), add:

```erb
      <%# Goal %>
      <% if @agent.goal.present? %>
        <div class="agent-detail__card">
          <h2 class="agent-detail__card-title">Goal</h2>
          <p class="agent-detail__goal-name">
            <%= link_to @agent.goal.title, goal_path(@agent.goal) %>
          </p>
          <% if @agent.goal.mission? %>
            <span class="goal-tree__label goal-tree__label--mission">Mission</span>
          <% end %>

          <% if @eval_total && @eval_total > 0 %>
            <dl class="agent-detail__kv">
              <div class="agent-detail__kv-row">
                <dt>Evaluations</dt>
                <dd><%= @eval_total %> total</dd>
              </div>
              <div class="agent-detail__kv-row">
                <dt>Pass rate</dt>
                <dd><%= (@eval_pass_count.to_f / @eval_total * 100).round %>%</dd>
              </div>
            </dl>

            <h3 class="agent-detail__card-subtitle">Recent Evaluations</h3>
            <div class="eval-list">
              <% @goal_evaluations.each do |evaluation| %>
                <div class="eval-item eval-item--<%= evaluation.result %>">
                  <span class="eval-item__badge eval-item__badge--<%= evaluation.result %>">
                    <%= evaluation.result.upcase %>
                  </span>
                  <span class="eval-item__task">
                    <%= link_to evaluation.task.title, task_path(evaluation.task) %>
                  </span>
                  <span class="eval-item__attempt">Attempt <%= evaluation.attempt_number %></span>
                  <time class="eval-item__time"><%= time_ago_in_words(evaluation.created_at) %> ago</time>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="agent-detail__empty-note">No evaluations yet. Evaluations appear when tasks are completed.</p>
          <% end %>
        </div>
      <% end %>
```

- [ ] **Step 3: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 4: Commit**

```bash
git add app/models/agent.rb app/controllers/agents_controller.rb app/views/agents/show.html.erb
git commit -m "Add goal section with evaluation stats to agent show page"
```

---

### Task 12: Task show page — Evaluations section

**Files:**
- Modify: `app/controllers/tasks_controller.rb:14-19` — load evaluations
- Modify: `app/views/tasks/show.html.erb:89-90` — add evaluations section

- [ ] **Step 1: Load evaluations in tasks controller show action**

In `app/controllers/tasks_controller.rb`, in the `show` action, after line 18 (`@task_document_links = ...`), add:

```ruby
    @goal_evaluations = @task.goal_evaluations.order(:attempt_number)
```

- [ ] **Step 2: Add evaluations section to task show page**

In `app/views/tasks/show.html.erb`, before the Conversation section (before the `<div class="task-detail__section">` containing `Conversation` — line 91), add:

```erb
    <% if @goal_evaluations.any? %>
      <div class="task-detail__section">
        <h2>Goal Evaluations</h2>
        <div class="eval-history">
          <% @goal_evaluations.each do |evaluation| %>
            <div class="eval-history__item eval-history__item--<%= evaluation.result %>">
              <div class="eval-history__header">
                <span class="eval-item__badge eval-item__badge--<%= evaluation.result %>">
                  <%= evaluation.result.upcase %>
                </span>
                <span class="eval-history__attempt">Attempt <%= evaluation.attempt_number %>/<%= GoalEvaluation::MAX_ATTEMPTS %></span>
                <time class="eval-history__time"><%= evaluation.created_at.strftime("%b %d, %Y at %H:%M") %></time>
              </div>
              <p class="eval-history__feedback"><%= evaluation.feedback %></p>
              <div class="eval-history__meta">
                <span>Goal: <%= link_to evaluation.goal.title, goal_path(evaluation.goal) %></span>
                <% if evaluation.cost_cents.present? %>
                  <span>Cost: <%= format_cents_as_dollars(evaluation.cost_cents) %></span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
```

- [ ] **Step 3: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/tasks_controller.rb app/views/tasks/show.html.erb
git commit -m "Add goal evaluations section to task show page"
```

---

### Task 13: Goal show page — Evaluation stats

**Files:**
- Modify: `app/controllers/goals_controller.rb` — load eval stats
- Modify: `app/views/goals/show.html.erb:25-35` — add eval stats alongside progress

- [ ] **Step 1: Load evaluation stats in goals controller**

In `app/controllers/goals_controller.rb`, in the `show` action, add after loading `@tasks` and `@children`:

```ruby
    goal_ids = [ @goal.id ] + @goal.descendant_ids
    @eval_total = GoalEvaluation.where(goal_id: goal_ids).count
    @eval_pass_count = GoalEvaluation.where(goal_id: goal_ids).passed.count
```

- [ ] **Step 2: Add evaluation stats to goal show page**

In `app/views/goals/show.html.erb`, inside the progress stats div (line 33), update from:

```erb
      <div class="goal-detail__progress-stats">
        <span><%= percentage %>% complete &middot; <%= @tasks.count { |t| t.status == "completed" } %> of <%= @tasks.size %> tasks done</span>
      </div>
```

to:

```erb
      <div class="goal-detail__progress-stats">
        <span><%= percentage %>% complete &middot; <%= @tasks.count { |t| t.status == "completed" } %> of <%= @tasks.size %> tasks done</span>
        <% if @eval_total > 0 %>
          <span class="goal-detail__eval-stats">&middot; <%= @eval_pass_count %>/<%= @eval_total %> evaluations passed (<%= (@eval_pass_count.to_f / @eval_total * 100).round %>%)</span>
        <% end %>
      </div>
```

- [ ] **Step 3: Run full test suite**

```bash
bin/rails test
```

Expected: No regressions.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/goals_controller.rb app/views/goals/show.html.erb
git commit -m "Add evaluation pass rate stats to goal show page"
```

---

### Task 14: Linting and security checks

- [ ] **Step 1: Run rubocop**

```bash
bin/rubocop
```

If there are violations, fix them with:

```bash
bin/rubocop -a
```

Then fix any remaining manual violations.

- [ ] **Step 2: Run brakeman**

```bash
bin/brakeman --quiet --no-pager
```

Expected: No new security warnings.

- [ ] **Step 3: Run full test suite one final time**

```bash
bin/rails test
```

Expected: All tests pass, no regressions.

- [ ] **Step 4: Commit any lint fixes**

```bash
git add -A
git commit -m "Fix rubocop and brakeman violations"
```

(Only if there were changes to commit.)

---

## Verification

After all tasks are complete:

1. **Unit tests pass:** `bin/rails test test/models/goal_evaluation_test.rb` — all green
2. **Service tests pass:** `bin/rails test test/services/goal_evaluation_service_test.rb` — all green
3. **Job tests pass:** `bin/rails test test/jobs/evaluate_goal_alignment_job_test.rb` — all green
4. **Full suite green:** `bin/rails test` — no regressions
5. **Lint clean:** `bin/rubocop` — no violations
6. **Security clean:** `bin/brakeman --quiet --no-pager` — no warnings
7. **Manual smoke test:** Start dev server (`bin/dev`), assign a goal to an agent, create a task for that agent, mark it complete, verify the evaluation job enqueues (check Solid Queue dashboard or logs)
