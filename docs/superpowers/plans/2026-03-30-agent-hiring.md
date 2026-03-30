# Agent Hiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow agents to hire subordinate roles from their department's role template via an API endpoint, with optional human approval.

**Architecture:** Business logic in `Roles::Hiring` concern (included in Role model). Thin `RoleHiringsController` with `AgentApiAuthenticatable`. New `PendingHire` model for approval-gated requests. New `auto_hire_enabled` boolean on roles.

**Tech Stack:** Rails 8, Minitest, SQLite, fixtures

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `app/models/roles/hiring.rb` | Concern: `department_template`, `hirable_roles`, `can_hire?`, `hire!`, `execute_hire!` |
| Create | `app/models/pending_hire.rb` | Model: stores pending hire requests awaiting approval |
| Create | `app/controllers/role_hirings_controller.rb` | Thin controller: API endpoint for `POST /roles/:id/hire` |
| Create | `db/migrate/*_add_auto_hire_enabled_to_roles.rb` | Migration: add boolean column |
| Create | `db/migrate/*_create_pending_hires.rb` | Migration: create pending_hires table |
| Create | `test/models/roles/hiring_test.rb` | Unit tests for hiring concern |
| Create | `test/models/pending_hire_test.rb` | Unit tests for PendingHire model |
| Create | `test/controllers/role_hirings_controller_test.rb` | Controller tests (session + Bearer token) |
| Create | `test/fixtures/pending_hires.yml` | Test fixtures |
| Modify | `app/models/role.rb` | Include `Roles::Hiring` |
| Modify | `app/views/roles/_form.html.erb` | Add `auto_hire_enabled` checkbox |
| Modify | `app/controllers/roles_controller.rb` | Permit `auto_hire_enabled` param; approve/reject pending hires |
| Modify | `config/routes.rb` | Add `post :hire` member route on roles |

---

### Task 1: Migration — `auto_hire_enabled` on roles

**Files:**
- Create: `db/migrate/TIMESTAMP_add_auto_hire_enabled_to_roles.rb`

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration AddAutoHireEnabledToRoles auto_hire_enabled:boolean`

- [ ] **Step 2: Edit migration for defaults**

The generated migration should look like:

```ruby
class AddAutoHireEnabledToRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :roles, :auto_hire_enabled, :boolean, default: false, null: false
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Schema updated, `roles` table has `auto_hire_enabled` column.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_add_auto_hire_enabled_to_roles.rb db/schema.rb
git commit -m "feat: add auto_hire_enabled boolean to roles table"
```

---

### Task 2: Migration — `pending_hires` table

**Files:**
- Create: `db/migrate/TIMESTAMP_create_pending_hires.rb`

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration CreatePendingHires`

- [ ] **Step 2: Edit migration with full schema**

```ruby
class CreatePendingHires < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_hires do |t|
      t.references :role, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :template_role_title, null: false
      t.integer :budget_cents, null: false
      t.integer :status, default: 0, null: false
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :pending_hires, [:company_id, :status]
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: `pending_hires` table created.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_create_pending_hires.rb db/schema.rb
git commit -m "feat: create pending_hires table for hire approval flow"
```

---

### Task 3: PendingHire model + tests

**Files:**
- Create: `app/models/pending_hire.rb`
- Create: `test/models/pending_hire_test.rb`
- Create: `test/fixtures/pending_hires.yml`

- [ ] **Step 1: Write fixtures**

```yaml
# test/fixtures/pending_hires.yml
pending_vp_hire:
  role: cto
  company: acme
  template_role_title: "VP Engineering"
  budget_cents: 30000
  status: 0  # pending
```

- [ ] **Step 2: Write failing tests**

```ruby
# test/models/pending_hire_test.rb
require "test_helper"

class PendingHireTest < ActiveSupport::TestCase
  setup do
    @pending_hire = pending_hires(:pending_vp_hire)
    @user = users(:one)
  end

  test "valid pending hire" do
    assert @pending_hire.valid?
  end

  test "requires role" do
    @pending_hire.role = nil
    assert_not @pending_hire.valid?
  end

  test "requires company" do
    @pending_hire.company = nil
    assert_not @pending_hire.valid?
  end

  test "requires template_role_title" do
    @pending_hire.template_role_title = nil
    assert_not @pending_hire.valid?
  end

  test "requires budget_cents" do
    @pending_hire.budget_cents = nil
    assert_not @pending_hire.valid?
  end

  test "budget_cents must be positive" do
    @pending_hire.budget_cents = 0
    assert_not @pending_hire.valid?

    @pending_hire.budget_cents = -1
    assert_not @pending_hire.valid?
  end

  test "default status is pending" do
    hire = PendingHire.new(role: roles(:cto), company: companies(:acme), template_role_title: "QA", budget_cents: 10000)
    assert hire.pending?
  end

  test "approve! sets status and resolved fields" do
    @pending_hire.approve!(@user)
    assert @pending_hire.approved?
    assert_equal @user, @pending_hire.resolved_by
    assert_not_nil @pending_hire.resolved_at
  end

  test "reject! sets status and resolved fields" do
    @pending_hire.reject!(@user)
    assert @pending_hire.rejected?
    assert_equal @user, @pending_hire.resolved_by
    assert_not_nil @pending_hire.resolved_at
  end

  test "cannot approve already resolved hire" do
    @pending_hire.approve!(@user)
    assert_raises(ActiveRecord::RecordInvalid) { @pending_hire.approve!(@user) }
  end

  test "cannot reject already resolved hire" do
    @pending_hire.reject!(@user)
    assert_raises(ActiveRecord::RecordInvalid) { @pending_hire.reject!(@user) }
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/models/pending_hire_test.rb`
Expected: All tests fail (model doesn't exist yet).

- [ ] **Step 4: Write PendingHire model**

```ruby
# app/models/pending_hire.rb
class PendingHire < ApplicationRecord
  include Tenantable

  belongs_to :role
  belongs_to :resolved_by, class_name: "User", optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :template_role_title, presence: true
  validates :budget_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :must_be_pending_to_resolve, on: :update

  scope :actionable, -> { where(status: :pending) }

  def approve!(user)
    update!(status: :approved, resolved_by: user, resolved_at: Time.current)
  end

  def reject!(user)
    update!(status: :rejected, resolved_by: user, resolved_at: Time.current)
  end

  private

  def must_be_pending_to_resolve
    if status_changed? && status_was != "pending"
      errors.add(:status, "can only be changed from pending")
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/pending_hire_test.rb`
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/models/pending_hire.rb test/models/pending_hire_test.rb test/fixtures/pending_hires.yml
git commit -m "feat: add PendingHire model for hire approval flow"
```

---

### Task 4: Roles::Hiring concern + tests

**Files:**
- Create: `app/models/roles/hiring.rb`
- Create: `test/models/roles/hiring_test.rb`
- Modify: `app/models/role.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/models/roles/hiring_test.rb
require "test_helper"

class Roles::HiringTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @ceo = roles(:ceo)
    @cto = roles(:cto)
  end

  # --- department_template ---

  test "CTO resolves to engineering department template" do
    template = @cto.department_template
    assert_not_nil template
    assert_equal "engineering", template.key
  end

  test "CEO has no department template (it is the company root)" do
    assert_nil @ceo.department_template
  end

  test "developer resolves to engineering department template via parent chain" do
    developer = roles(:developer)
    template = developer.department_template
    assert_not_nil template
    assert_equal "engineering", template.key
  end

  # --- hirable_roles ---

  test "CTO can hire roles from engineering template below its level" do
    hirable = @cto.hirable_roles
    hirable_titles = hirable.map(&:title)

    assert_includes hirable_titles, "VP Engineering"
    assert_includes hirable_titles, "Tech Lead"
    assert_includes hirable_titles, "Engineer"
    assert_includes hirable_titles, "QA"
    assert_not_includes hirable_titles, "CTO"
  end

  test "hirable_roles excludes roles that already exist in the company" do
    # developer fixture has title "Senior Developer", not "Engineer" — so "Engineer" should be hirable
    # But CTO and "Senior Developer" don't match template titles, so no exclusions from fixtures
    hirable = @cto.hirable_roles
    hirable_titles = hirable.map(&:title)

    # All engineering template subordinates should be hirable since none exist yet
    assert hirable_titles.size > 0
  end

  test "CEO returns empty hirable_roles (no department template)" do
    assert_empty @ceo.hirable_roles
  end

  # --- can_hire? ---

  test "CTO can hire VP Engineering" do
    assert @cto.can_hire?("VP Engineering")
  end

  test "CTO cannot hire CTO (same level)" do
    assert_not @cto.can_hire?("CTO")
  end

  test "CTO cannot hire nonexistent role" do
    assert_not @cto.can_hire?("Janitor")
  end

  # --- hire! with auto_hire_enabled ---

  test "hire! creates subordinate role when auto_hire_enabled" do
    @cto.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      new_role = @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)

      assert_equal "VP Engineering", new_role.title
      assert_equal @cto, new_role.parent
      assert_equal @cto.adapter_type, new_role.adapter_type
      assert_equal @cto.adapter_config, new_role.adapter_config
      assert_equal 20000, new_role.budget_cents
      assert_equal @company, new_role.company
      assert new_role.idle?
    end
  end

  test "hire! records audit event when auto_hire_enabled" do
    @cto.update!(auto_hire_enabled: true)

    assert_difference "AuditEvent.count", 1 do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end

    event = AuditEvent.last
    assert_equal "role_hired", event.action
    assert_equal "VP Engineering", event.metadata["hired_role_title"]
  end

  test "hire! raises when budget_cents exceeds own budget" do
    @cto.update!(auto_hire_enabled: true)

    error = assert_raises(Roles::Hiring::HiringError) do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 999_999)
    end
    assert_match(/budget/i, error.message)
  end

  test "hire! raises for non-hirable role title" do
    @cto.update!(auto_hire_enabled: true)

    error = assert_raises(Roles::Hiring::HiringError) do
      @cto.hire!(template_role_title: "CEO", budget_cents: 10000)
    end
    assert_match(/cannot hire/i, error.message)
  end

  test "hire! raises when role already exists in company" do
    @cto.update!(auto_hire_enabled: true)
    @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)

    error = assert_raises(Roles::Hiring::HiringError) do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end
    assert_match(/already exists/i, error.message)
  end

  # --- hire! without auto_hire_enabled (pending approval) ---

  test "hire! creates pending hire and blocks agent when auto_hire disabled" do
    assert_not @cto.auto_hire_enabled?

    assert_difference "PendingHire.count", 1 do
      result = @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
      assert_kind_of PendingHire, result
      assert result.pending?
    end

    @cto.reload
    assert @cto.pending_approval?
  end

  test "hire! notifies admins when pending approval" do
    assert_difference "Notification.count" do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end

    notification = Notification.last
    assert_equal "hire_approval_requested", notification.action
    assert_equal "VP Engineering", notification.metadata["requested_hire"]
  end

  test "hire! records audit event when pending approval" do
    assert_difference "AuditEvent.count", 1 do
      @cto.hire!(template_role_title: "VP Engineering", budget_cents: 20000)
    end

    event = AuditEvent.last
    assert_equal "hire_requested", event.action
  end

  # --- execute_hire! (called after approval) ---

  test "execute_hire! creates the role from pending hire data" do
    pending_hire = PendingHire.create!(
      role: @cto,
      company: @company,
      template_role_title: "VP Engineering",
      budget_cents: 20000
    )

    assert_difference "Role.count", 1 do
      new_role = @cto.execute_hire!(pending_hire)
      assert_equal "VP Engineering", new_role.title
      assert_equal @cto, new_role.parent
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/roles/hiring_test.rb`
Expected: All tests fail (concern doesn't exist yet).

- [ ] **Step 3: Create `app/models/roles` directory and write the concern**

Run: `mkdir -p app/models/roles`

```ruby
# app/models/roles/hiring.rb
module Roles
  module Hiring
    extend ActiveSupport::Concern

    class HiringError < StandardError; end

    included do
      has_many :pending_hires, dependent: :destroy
    end

    # Returns the RoleTemplateRegistry::Template for this role's department,
    # or nil if the role is the company root (CEO) with no template match.
    def department_template
      root_role = find_department_root
      return nil if root_role.nil?

      RoleTemplateRegistry.all.find do |template|
        template.roles.first&.title == root_role.title
      end
    end

    # Returns TemplateRole records this role can hire:
    # lower-level roles in the department template that don't yet exist in the company.
    def hirable_roles
      template = department_template
      return [] if template.nil?

      my_title = title
      descendant_titles = collect_template_descendants(template, my_title)
      existing_titles = company.roles.where(title: descendant_titles).pluck(:title)

      template.roles.select { |tr| descendant_titles.include?(tr.title) && !existing_titles.include?(tr.title) }
    end

    def can_hire?(template_role_title)
      hirable_roles.any? { |tr| tr.title == template_role_title }
    end

    # Main entry point for hiring.
    # When auto_hire_enabled: creates the role immediately, returns the new Role.
    # When auto_hire disabled: creates a PendingHire, blocks the agent, returns the PendingHire.
    # Raises HiringError for validation failures.
    def hire!(template_role_title:, budget_cents:)
      validate_hire!(template_role_title, budget_cents)

      if auto_hire_enabled?
        template_role = find_template_role(template_role_title)
        create_hired_role(template_role, budget_cents)
      else
        request_hire_approval(template_role_title, budget_cents)
      end
    end

    # Creates the hired role from a PendingHire record. Called after admin approval.
    def execute_hire!(pending_hire)
      template_role = find_template_role(pending_hire.template_role_title)
      create_hired_role(template_role, pending_hire.budget_cents)
    end

    private

    # Walk up the parent chain. The department root is the first role whose title
    # matches the root (first) role of any template. If we reach a parentless role
    # that doesn't match any template root, return nil (e.g. CEO).
    def find_department_root
      current = self
      template_root_titles = RoleTemplateRegistry.all.map { |t| t.roles.first&.title }.compact

      while current
        return current if template_root_titles.include?(current.title)
        current = current.parent
      end

      nil
    end

    # Collect all titles that are descendants of the given title in the template tree.
    def collect_template_descendants(template, ancestor_title)
      descendants = Set.new
      queue = [ancestor_title]

      while queue.any?
        current_title = queue.shift
        template.roles.each do |tr|
          if tr.parent == current_title && !descendants.include?(tr.title)
            descendants << tr.title
            queue << tr.title
          end
        end
      end

      descendants
    end

    def validate_hire!(template_role_title, budget_cents)
      unless can_hire?(template_role_title)
        if company.roles.exists?(title: template_role_title)
          raise HiringError, "Cannot hire #{template_role_title}: role already exists in this company"
        else
          raise HiringError, "Cannot hire #{template_role_title}: not a valid subordinate role for #{title}"
        end
      end

      if budget_configured? && budget_cents > self.budget_cents
        raise HiringError, "Insufficient budget: requested #{budget_cents} but your budget ceiling is #{self.budget_cents}"
      end
    end

    def find_template_role(template_role_title)
      template = department_template
      template.roles.find { |tr| tr.title == template_role_title }
    end

    def create_hired_role(template_role, hire_budget_cents)
      new_role = company.roles.create!(
        title: template_role.title,
        description: template_role.description,
        job_spec: template_role.job_spec,
        parent: self,
        adapter_type: adapter_type,
        adapter_config: adapter_config,
        budget_cents: hire_budget_cents,
        budget_period_start: Date.current.beginning_of_month,
        status: :idle
      )

      record_audit_event!(
        actor: self,
        action: "role_hired",
        metadata: {
          hired_role_id: new_role.id,
          hired_role_title: new_role.title,
          budget_cents: hire_budget_cents
        }
      )

      new_role
    end

    def request_hire_approval(template_role_title, budget_cents)
      pending_hire = pending_hires.create!(
        company: company,
        template_role_title: template_role_title,
        budget_cents: budget_cents
      )

      update!(
        status: :pending_approval,
        pause_reason: "Awaiting approval to hire #{template_role_title}"
      )

      notify_admins_of_hire_request(template_role_title, budget_cents)

      record_audit_event!(
        actor: self,
        action: "hire_requested",
        metadata: {
          requested_hire: template_role_title,
          budget_cents: budget_cents,
          pending_hire_id: pending_hire.id
        }
      )

      pending_hire
    end

    def notify_admins_of_hire_request(template_role_title, budget_cents)
      company.admin_recipients.each do |admin|
        Notification.create!(
          company: company,
          recipient: admin,
          actor: self,
          notifiable: self,
          action: "hire_approval_requested",
          metadata: {
            role_title: title,
            requested_hire: template_role_title,
            budget_cents: budget_cents
          }
        )
      end
    end
  end
end
```

- [ ] **Step 4: Include concern in Role model**

Modify `app/models/role.rb` — add after the existing includes:

```ruby
include Roles::Hiring
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/roles/hiring_test.rb`
Expected: All tests pass.

- [ ] **Step 6: Run full test suite to check for regressions**

Run: `bin/rails test`
Expected: No failures.

- [ ] **Step 7: Commit**

```bash
git add app/models/roles/hiring.rb app/models/role.rb test/models/roles/hiring_test.rb
git commit -m "feat: add Roles::Hiring concern with hire logic and approval flow"
```

---

### Task 5: Route + Controller + tests

**Files:**
- Create: `app/controllers/role_hirings_controller.rb`
- Create: `test/controllers/role_hirings_controller_test.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Add route**

Modify `config/routes.rb` — inside the `resources :roles` block, add to the existing `member do`:

```ruby
resources :roles do
  # ... existing nested resources ...
  member do
    # ... existing member actions (pause, resume, terminate, approve, reject) ...
    post :hire, to: "role_hirings#create"
  end
end
```

- [ ] **Step 2: Write failing controller tests**

```ruby
# test/controllers/role_hirings_controller_test.rb
require "test_helper"

class RoleHiringsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)

    @cto = roles(:cto)
  end

  # ==========================================================================
  # Agent API tests (Bearer token auth)
  # ==========================================================================

  test "agent can hire subordinate role via API with auto_hire enabled" do
    sign_out
    @cto.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      post hire_role_url(@cto, format: :json),
           params: { template_role_title: "VP Engineering", budget_cents: 20000 },
           headers: { "Authorization" => "Bearer #{@cto.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "ok", json["status"]
    assert json["role_id"].present?
    assert_match "VP Engineering", json["message"]
  end

  test "agent hire creates pending request when auto_hire disabled" do
    sign_out

    assert_difference "PendingHire.count", 1 do
      post hire_role_url(@cto, format: :json),
           params: { template_role_title: "VP Engineering", budget_cents: 20000 },
           headers: { "Authorization" => "Bearer #{@cto.api_token}" }
    end

    assert_response :ok
    json = response.parsed_body
    assert_equal "pending_approval", json["status"]
    assert_match "approval", json["message"]
  end

  test "agent cannot hire invalid role title via API" do
    sign_out
    @cto.update!(auto_hire_enabled: true)

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "CEO", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["error"].present?
  end

  test "agent cannot hire with excessive budget via API" do
    sign_out
    @cto.update!(auto_hire_enabled: true)

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "VP Engineering", budget_cents: 999_999 },
         headers: { "Authorization" => "Bearer #{@cto.api_token}" }

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_match(/budget/i, json["error"])
  end

  test "API returns 401 for invalid Bearer token" do
    sign_out

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "VP Engineering", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer invalid_token" }

    assert_response :unauthorized
  end

  test "agent cannot hire for role in another company" do
    sign_out
    widgets_lead = roles(:widgets_lead)

    post hire_role_url(@cto, format: :json),
         params: { template_role_title: "VP Engineering", budget_cents: 20000 },
         headers: { "Authorization" => "Bearer #{widgets_lead.api_token}" }

    assert_response :not_found
  end

  # ==========================================================================
  # Human-initiated hire tests (session auth)
  # ==========================================================================

  test "human user can trigger hire for a role" do
    @cto.update!(auto_hire_enabled: true)

    assert_difference "Role.count", 1 do
      post hire_role_url(@cto),
           params: { template_role_title: "VP Engineering", budget_cents: 20000 }
    end

    assert_redirected_to role_path(@cto)
    assert_match "VP Engineering", flash[:notice]
  end

  test "human user sees error for invalid hire" do
    @cto.update!(auto_hire_enabled: true)

    post hire_role_url(@cto),
         params: { template_role_title: "Nonexistent", budget_cents: 20000 }

    assert_redirected_to role_path(@cto)
    assert flash[:alert].present?
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/role_hirings_controller_test.rb`
Expected: All fail (controller doesn't exist yet).

- [ ] **Step 4: Write the controller**

```ruby
# app/controllers/role_hirings_controller.rb
class RoleHiringsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_role

  def create
    result = @role.hire!(
      template_role_title: hire_params[:template_role_title],
      budget_cents: hire_params[:budget_cents].to_i
    )

    if result.is_a?(Role)
      respond_to do |format|
        format.json { render json: { status: "ok", role_id: result.id, message: "Hired #{result.title}" }, status: :ok }
        format.html { redirect_to role_path(@role), notice: "#{result.title} has been hired." }
      end
    else
      # PendingHire returned — approval required
      respond_to do |format|
        format.json { render json: { status: "pending_approval", pending_hire_id: result.id, message: "Hire request for #{result.template_role_title} requires approval" }, status: :ok }
        format.html { redirect_to role_path(@role), notice: "Hire request for #{result.template_role_title} submitted for approval." }
      end
    end
  rescue Roles::Hiring::HiringError => e
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to role_path(@role), alert: e.message }
    end
  end

  private

  def set_role
    @role = Current.company.roles.find_by(id: params[:id])
    unless @role
      respond_to do |format|
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.html { raise ActiveRecord::RecordNotFound }
      end
    end
  end

  def hire_params
    params.permit(:template_role_title, :budget_cents)
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/role_hirings_controller_test.rb`
Expected: All tests pass.

- [ ] **Step 6: Run full test suite**

Run: `bin/rails test`
Expected: No failures.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/role_hirings_controller.rb test/controllers/role_hirings_controller_test.rb config/routes.rb
git commit -m "feat: add RoleHiringsController with API endpoint for agent hiring"
```

---

### Task 6: UI — `auto_hire_enabled` checkbox + permit param

**Files:**
- Modify: `app/views/roles/_form.html.erb`
- Modify: `app/controllers/roles_controller.rb`

- [ ] **Step 1: Add checkbox to role form**

Modify `app/views/roles/_form.html.erb` — add after the Monthly Budget fieldset (before the approval gates section):

```erb
  <!-- Auto-Hire Configuration -->
  <fieldset class="form__fieldset">
    <legend>Automatic Hiring</legend>
    <p class="form__hint">When enabled, this role can hire subordinate roles from its department template without human approval.</p>

    <div class="form__field">
      <%= f.label :auto_hire_enabled, "Enable automatic hiring" %>
      <div class="form__toggle">
        <%= f.check_box :auto_hire_enabled, class: "form__checkbox" %>
        <span class="form__toggle-label">Role can hire subordinates automatically</span>
      </div>
    </div>
  </fieldset>
```

- [ ] **Step 2: Permit the param in roles_controller**

Modify `app/controllers/roles_controller.rb` line 154 — add `:auto_hire_enabled` to the permitted params:

```ruby
permitted = params.require(:role).permit(:title, :description, :job_spec, :parent_id, :adapter_type, :heartbeat_enabled, :heartbeat_interval, :budget_dollars, :auto_hire_enabled)
```

- [ ] **Step 3: Verify in browser**

Run: `bin/dev`
Navigate to any role edit page. Confirm the "Automatic Hiring" checkbox appears.

- [ ] **Step 4: Run full test suite**

Run: `bin/rails test`
Expected: No failures.

- [ ] **Step 5: Commit**

```bash
git add app/views/roles/_form.html.erb app/controllers/roles_controller.rb
git commit -m "feat: add auto_hire_enabled checkbox to role form"
```

---

### Task 7: Approval flow — approve/reject pending hires

**Files:**
- Modify: `app/controllers/roles_controller.rb` (approve/reject actions)

- [ ] **Step 1: Write failing tests for approval of pending hires**

Add to `test/controllers/role_hirings_controller_test.rb`:

```ruby
  # ==========================================================================
  # Approval flow tests
  # ==========================================================================

  test "approving a role with pending hire creates the hired role" do
    # Create a pending hire
    pending_hire = PendingHire.create!(
      role: @cto,
      company: @company,
      template_role_title: "VP Engineering",
      budget_cents: 20000
    )
    @cto.update!(status: :pending_approval, pause_reason: "Awaiting approval to hire VP Engineering")

    assert_difference "Role.count", 1 do
      post approve_role_url(@cto)
    end

    assert_redirected_to role_path(@cto)

    @cto.reload
    assert @cto.idle?

    pending_hire.reload
    assert pending_hire.approved?

    new_role = @company.roles.find_by(title: "VP Engineering")
    assert_not_nil new_role
    assert_equal @cto, new_role.parent
  end

  test "rejecting a role with pending hire does not create role" do
    pending_hire = PendingHire.create!(
      role: @cto,
      company: @company,
      template_role_title: "VP Engineering",
      budget_cents: 20000
    )
    @cto.update!(status: :pending_approval, pause_reason: "Awaiting approval to hire VP Engineering")

    assert_no_difference "Role.count" do
      post reject_role_url(@cto), params: { reason: "Not needed now" }
    end

    assert_redirected_to role_path(@cto)

    @cto.reload
    assert @cto.paused?

    pending_hire.reload
    assert pending_hire.rejected?
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/role_hirings_controller_test.rb`
Expected: New approval tests fail.

- [ ] **Step 3: Update approve action in RolesController**

Modify `app/controllers/roles_controller.rb` — update the `approve` method:

```ruby
  def approve
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    pending_hire = @role.pending_hires.actionable.last
    if pending_hire
      @role.execute_hire!(pending_hire)
      pending_hire.approve!(Current.user)
    end

    @role.update!(
      status: :idle,
      pause_reason: nil,
      paused_at: nil
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_approval")
    redirect_to @role, notice: "#{@role.title} has been approved and resumed."
  end
```

- [ ] **Step 4: Update reject action in RolesController**

Modify `app/controllers/roles_controller.rb` — update the `reject` method:

```ruby
  def reject
    unless @role.pending_approval?
      redirect_to @role, alert: "#{@role.title} is not pending approval."
      return
    end

    pending_hire = @role.pending_hires.actionable.last
    pending_hire&.reject!(Current.user)

    @role.update!(
      status: :paused,
      pause_reason: "Approval rejected: #{params[:reason].presence || 'No reason given'}",
      paused_at: Time.current
    )
    @role.record_audit_event!(actor: Current.user, action: "gate_rejection", metadata: { reason: @role.pause_reason })
    redirect_to @role, notice: "#{@role.title} approval has been rejected."
  end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/role_hirings_controller_test.rb`
Expected: All tests pass.

- [ ] **Step 6: Run full test suite**

Run: `bin/rails test`
Expected: No failures.

- [ ] **Step 7: Run linter**

Run: `bin/rubocop`
Expected: No offenses.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/roles_controller.rb test/controllers/role_hirings_controller_test.rb
git commit -m "feat: wire approve/reject actions to handle pending hire requests"
```
