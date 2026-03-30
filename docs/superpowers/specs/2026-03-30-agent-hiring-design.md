# Agent Hiring — Design Spec

## Problem

C-level agents (CTO, CMO, CFO, COO) have a responsibility to hire subordinates to perform their assigned goals rather than doing the work themselves. Currently, role creation is exclusively a human action through the web UI. Agents have no API endpoint to create subordinate roles.

## Requirements

1. Agents can hire subordinate roles from their department's role template
2. Agents can only hire roles at a lower level in the template hierarchy (never same-level or higher)
3. Roles that already exist in the company cannot be hired again (idempotent, respects uniqueness constraint)
4. Hired roles inherit adapter_type and adapter_config from the hiring agent (immediately operational)
5. Hiring agent must specify a monthly budget for the new role, not exceeding its own budget ceiling
6. By default, hiring requires human approval (`auto_hire_enabled: false`). When enabled, agents hire automatically
7. When approval is required, the agent is blocked (`pending_approval`) until an admin approves or rejects

## Architecture

### Business Logic: `app/models/roles/hiring.rb`

A concern included in the Role model. Contains all hiring domain logic.

**Public API:**

```ruby
# Returns TemplateRole records this role can hire (lower-level, not yet in company)
role.hirable_roles

# Predicate: can this role hire the given template role title?
role.can_hire?("VP Engineering")

# Performs the hire. Returns the new Role on success.
# Raises or returns error info when blocked/invalid.
role.hire!(template_role_title: "VP Engineering", budget_cents: 50_000)

# Which department template does this role belong to?
role.department_template
```

**`department_template` resolution:**
Walk up the role's parent chain to find the root (parentless) role. Match that root's title against `RoleTemplateRegistry` to find the department template. The CEO is not in any template — C-level roles are the roots of their department templates.

**`hirable_roles` logic:**
1. Resolve department template
2. Find this role's position in the template hierarchy
3. Return all template roles that are descendants of this role in the template tree
4. Exclude roles whose titles already exist in the company

**`hire!` logic:**
1. Validate `template_role_title` is in `hirable_roles`
2. Validate `budget_cents` > 0 and <= hiring agent's own `budget_cents`
3. If `auto_hire_enabled` is `false`:
   - Create a `PendingHire` record with request details
   - Set self to `pending_approval` status
   - Notify company admins
   - Record audit event (`hire_requested`)
   - Return/raise indicating pending status
4. If `auto_hire_enabled` is `true`:
   - Execute the hire (see `execute_hire!` below)

**`execute_hire!` (called directly or after approval):**
1. Create the new role with:
   - `title`, `description`, `job_spec` from template
   - `parent`: the hiring agent
   - `adapter_type`, `adapter_config`: inherited from hiring agent
   - `budget_cents`: the requested amount (monthly ceiling for the new role)
   - `budget_period_start`: beginning of current month
   - `status`: `idle`
2. Validate requested `budget_cents` does not exceed hiring agent's own `budget_cents` (a subordinate's monthly budget should not exceed its manager's)
3. Skills auto-assigned via existing `assign_default_skills` callback
4. API token auto-generated via existing `generate_api_token` callback
5. Record audit event (`role_hired`)
6. Return the new role

**Note on budget model:** `budget_cents` is a monthly ceiling, not a balance. The hiring agent sets a monthly budget for the new hire. We validate the new hire's budget does not exceed the hiring agent's own budget — a subordinate should not have a larger allowance than its manager.

### New Model: `PendingHire`

Persists hire requests that need approval.

**Schema:**
```
pending_hires
  role_id          :integer, not null (FK to roles — the hiring agent)
  company_id       :integer, not null (FK to companies — tenant scoping)
  template_role_title :string, not null
  budget_cents     :integer, not null
  status           :integer, not null, default: 0 (pending: 0, approved: 1, rejected: 2)
  resolved_by_id   :integer (FK to users — who approved/rejected)
  resolved_at      :datetime
  timestamps
```

**Approval flow:**
- Admin sees pending hires (via notification or a dedicated UI section)
- On approve: calls `pending_hire.approve!(user)` which triggers `role.execute_hire!` using the stored params
- On reject: calls `pending_hire.reject!(user)` which returns the hiring agent to `idle` status

### New Field on Role: `auto_hire_enabled`

- Type: boolean, default: `false`
- Migration: `add_column :roles, :auto_hire_enabled, :boolean, default: false, null: false`
- Exposed as checkbox in `roles/_form.html.erb`
- Permitted in `roles_controller.rb` params

### Controller: `RoleHiringsController`

Thin controller. Includes `AgentApiAuthenticatable`.

```ruby
# POST /roles/:id/hire
# Params: { template_role_title: "VP Engineering", budget_cents: 50000 }
```

**Success (auto-hire):**
```json
{ "status": "ok", "role_id": 123, "message": "Hired VP Engineering" }
```

**Pending approval:**
```json
{ "status": "pending_approval", "message": "Hire request for VP Engineering requires approval" }
```

**Errors (422):**
```json
{ "error": "Cannot hire VP Engineering: role already exists in this company" }
{ "error": "Cannot hire CEO: role is not below your level in the hierarchy" }
{ "error": "Insufficient budget: requested 50000 but only 30000 remaining" }
```

### Route

```ruby
resources :roles do
  member do
    post :hire, to: "role_hirings#create"
  end
end
```

### Notifications

When a hire is pending approval, notify all company admins:
- `action`: `"hire_approval_requested"`
- `metadata`: `{ role_title: "CTO", requested_hire: "VP Engineering", budget_cents: 50000 }`

### Audit Events

- `hire_requested` — when auto_hire is off and agent requests a hire
- `role_hired` — when a role is successfully created via hiring
- `hire_approved` / `hire_rejected` — when admin resolves a pending hire

## Files to Create

| File | Purpose |
|------|---------|
| `app/models/roles/hiring.rb` | Concern with hiring business logic |
| `app/models/pending_hire.rb` | Model for pending hire requests |
| `app/controllers/role_hirings_controller.rb` | API endpoint for agent hiring |
| `db/migrate/*_add_auto_hire_enabled_to_roles.rb` | Add boolean field |
| `db/migrate/*_create_pending_hires.rb` | Create pending_hires table |
| `test/models/roles/hiring_test.rb` | Unit tests for hiring logic |
| `test/models/pending_hire_test.rb` | Unit tests for pending hire model |
| `test/controllers/role_hirings_controller_test.rb` | Controller tests |
| `test/fixtures/pending_hires.yml` | Test fixtures |

## Files to Modify

| File | Change |
|------|--------|
| `app/models/role.rb` | Include `Roles::Hiring` concern |
| `app/views/roles/_form.html.erb` | Add `auto_hire_enabled` checkbox |
| `config/routes.rb` | Add `post :hire` member route |
| `app/controllers/roles_controller.rb` | Permit `auto_hire_enabled` param |

## Verification

1. `bin/rails test test/models/roles/hiring_test.rb` — hiring logic unit tests
2. `bin/rails test test/models/pending_hire_test.rb` — pending hire model tests
3. `bin/rails test test/controllers/role_hirings_controller_test.rb` — API endpoint tests
4. `bin/rails test` — full suite passes
5. `bin/rubocop` — no style violations
6. Manual: verify checkbox appears in role form, API responds correctly with Bearer token auth
