# Domain Pitfalls: Builtin Role Templates (Org Chart Seeding)

**Domain:** Hierarchical template application with bulk role creation, skill pre-assignment, and duplicate detection
**Stack:** Rails 8 + SQLite + Existing Role/Skill models with callbacks
**Researched:** 2026-03-29
**Scope:** Adding 3-5 builtin department templates to an existing multi-tenant system

---

## Critical Pitfalls

Mistakes that cause data corruption, cross-tenant leaks, or require rewrites.

---

### Pitfall 1: Parent Role Created After Child -- Foreign Key and Validation Failure

**What goes wrong:** The YAML template defines roles in a flat list or hash. The code iterates the list and creates each role, looking up the parent by title. If the YAML ordering happens to list a child before its parent (e.g., "Developer" appears before "Tech Lead"), the parent lookup returns nil. The child is created as a root node or the creation fails on a NOT NULL constraint if parent presence is enforced.

**Why it happens:** YAML hashes in Ruby preserve insertion order (Ruby 1.9+), but this is only safe if the template author explicitly orders parents before children. When templates are edited, reordered, or generated, this ordering guarantee breaks silently. The problem is compounded when templates have multiple levels (CTO -> Tech Lead -> Developer) -- any reordering breaks the chain.

**Consequences:** Roles created as orphaned root nodes instead of nested under the correct parent. The org chart looks flat instead of hierarchical. If the template application is not wrapped in a transaction, some roles are created correctly and others are orphans -- a partially applied template that is painful to clean up. The `TreeHierarchy` concern's `parent_belongs_to_same_company` validation will pass (nil parent is allowed), so this fails silently.

**Prevention:**
- Use a two-pass approach: first pass creates all roles without parent assignments (or with a temporary lookup hash), second pass assigns parent_ids. This is order-independent.
- Alternatively, topologically sort the YAML template entries by depth before processing. Walk the tree breadth-first: roots first, then depth 1, then depth 2.
- Store parent references as strings (title references) in the YAML and resolve them against the in-memory hash of already-created roles. Use `fetch` with a clear error:
  ```ruby
  created_roles = {}
  sorted_entries.each do |entry|
    parent = entry[:parent] ? created_roles.fetch(entry[:parent]) { raise "Parent '#{entry[:parent]}' not yet created" } : attach_point
    created_roles[entry[:title]] = company.roles.create!(title: entry[:title], parent: parent, ...)
  end
  ```
- Write a test that shuffles the YAML entries and asserts template application still produces the correct hierarchy.

**Detection:** Roles appear at the root level of the org chart that should be nested. `Role.roots.count` is unexpectedly high after template application.

**Confidence:** HIGH -- This exact pattern exists in the codebase's `db/seeds.rb` (lines 70-80) where it works only because `role_defs` is carefully ordered. The pattern breaks when moved to user-triggered template application with YAML files that may be reordered.

---

### Pitfall 2: ConfigVersioned Callback Fires for Every Bulk-Created Role

**What goes wrong:** The template application creates 5-8 roles in a loop. Each `Role.create!` triggers the `ConfigVersioned` concern's `after_save :create_config_version` callback. This creates 5-8 `ConfigVersion` records, one per role. The `create_config_version` method reads `Current.user` for the `author` field. When template application runs from a service object or controller action, `Current.user` may be set correctly. But when run from a seed task, rake task, or console, `Current.user` is nil -- the ConfigVersion records are created with `author: nil`, losing traceability.

**Why it happens:** The `ConfigVersioned` concern fires on every `save` where governance attributes changed. Role creation changes `title`, `description`, `parent_id`, and `job_spec` -- all listed in `governance_attributes`. The concern is designed for interactive edits, not bulk programmatic creation. There is no mechanism to suppress it during template application.

**Consequences:**
- 5-8 ConfigVersion records per template application, cluttering the version history with "system-generated" entries that have no human author.
- With `Current.user` nil, the `author` field is nil (it is `optional: true`), which may confuse governance audit trails -- these look like ghost edits.
- Each ConfigVersion write is a separate SQLite write within the transaction, adding write pressure.
- If the user applies multiple templates, the config version history becomes dominated by template application noise rather than meaningful human edits.

**Prevention:**
- Wrap template application in a `Role.skip_callback(:save, :after, :create_config_version)` block, then re-enable after:
  ```ruby
  Role.skip_callback(:save, :after, :create_config_version) do
    # ... create roles ...
  end
  ```
  Caution: `skip_callback` is not thread-safe in older Rails versions. In Rails 8, prefer `suppress` or a flag-based approach.
- Better approach: add an attribute flag to Role (e.g., `attr_accessor :skip_config_versioning`) and modify `should_version?` to check it:
  ```ruby
  def should_version?
    return false if skip_config_versioning
    # ... existing logic ...
  end
  ```
- If config versions ARE desired for audit trail, create a single summary ConfigVersion record after the entire template is applied, rather than one per role.

**Detection:** `ConfigVersion.count` spikes unexpectedly after template application. Config version history for a company shows a burst of "create" entries with nil author.

**Confidence:** HIGH -- Verified by reading the `ConfigVersioned` concern (lines 31-35 in `config_versioned.rb`): `should_version?` returns true for any save that changes governance attributes, and `governance_attributes` in Role includes `title`, `description`, `parent_id`, `job_spec`, `budget_cents`, `budget_period_start`, and `status`.

---

### Pitfall 3: Cross-Tenant Skill Reference -- Template Assigns Skills from Wrong Company

**What goes wrong:** The template specifies skill keys (e.g., `["code_review", "architecture_planning"]`) to pre-assign to each role. The code looks up skills by key but forgets to scope to the current company. `Skill.find_by(key: "code_review")` returns the first match across ALL companies. If Company A's template application runs and Company B was created first, the skill from Company B is assigned to Company A's role. The `RoleSkill` cross-company validation catches this -- but only at the ActiveRecord level. If the code uses `insert_all` or raw SQL for performance, the validation is bypassed entirely.

**Why it happens:** The `Tenantable` concern provides `scope :for_current_company` which relies on `Current.company` being set. If the template application service does not set `Current.company`, the scope returns nothing. If it queries `Skill.find_by(key:)` without the company scope, it matches globally. The existing `assign_default_skills` method in Role (line 231) does this correctly: `company.skills.where(key: skill_keys)` -- but a new template application service might not follow this pattern.

**Consequences:** Skills from another tenant assigned to roles. This is a data isolation violation -- the most serious category of bug in a multi-tenant system. The `RoleSkill` validation (`skill_belongs_to_same_company`) will catch it at the ActiveRecord level, but the error message will be confusing ("Skill must belong to the same company as the role") and will halt template application mid-way through.

**Prevention:**
- ALWAYS resolve skills through the company association: `company.skills.where(key: skill_keys)`, never `Skill.where(key: skill_keys)`.
- The template application service should receive the company as an explicit parameter, not rely on `Current.company`:
  ```ruby
  class ApplyDepartmentTemplate
    def initialize(company:, template_key:, attach_to_role:)
      @company = company
      # ...
    end
  end
  ```
- Add a test that creates two companies, seeds skills in both, and verifies template application for Company A only references Company A's skills.
- The `RoleSkill#skill_belongs_to_same_company` validation is the last line of defense. Never bypass it with `insert_all` for role_skills.

**Detection:** `RoleSkill` records where `skill.company_id != role.company_id`. Run: `RoleSkill.joins(:role, :skill).where("roles.company_id != skills.company_id").count`.

**Confidence:** HIGH -- The cross-company validation exists in `RoleSkill` (lines 8-12) precisely because this is a known risk. The existing `assign_default_skills` in Role correctly scopes through `company.skills`.

---

### Pitfall 4: Duplicate Detection by Title Ignores Case and Whitespace Variations

**What goes wrong:** The template defines a role titled "Tech Lead". The company already has a role titled "tech lead" (lowercase) or "Tech Lead " (trailing space). The uniqueness validation on Role is `validates :title, uniqueness: { scope: :company_id }`. SQLite's default collation is BINARY, meaning "Tech Lead" and "tech lead" are different values. The duplicate detection check (`company.roles.find_by(title: entry[:title])`) returns nil. `Role.create!` succeeds. The database now has two roles that users perceive as duplicates but are technically distinct.

**Why it happens:** SQLite uses binary (case-sensitive) comparison by default for TEXT columns. The database unique index `index_roles_on_company_id_and_title` is also case-sensitive. Rails' `uniqueness` validation delegates to a SQL query which inherits this case sensitivity. The template YAML has "Tech Lead" but a user manually created "tech lead" -- both are valid, distinct database entries.

**Consequences:** Users see two roles with the same (to human eyes) title. The skip-duplicate logic fails to detect the existing role and creates a near-duplicate. If an agent is later assigned to one, the wrong "Tech Lead" might be selected in the UI. Confusion in the org chart.

**Prevention:**
- Normalize titles before comparison AND before storage. Add a `before_validation` callback:
  ```ruby
  before_validation :normalize_title
  def normalize_title
    self.title = title&.strip&.squeeze(" ")
  end
  ```
- For case-insensitive duplicate detection, use `where("LOWER(title) = LOWER(?)", entry[:title])` or SQLite's `COLLATE NOCASE`:
  ```ruby
  existing = company.roles.where("title COLLATE NOCASE = ?", entry[:title].strip).first
  ```
- Alternatively, add a `COLLATE NOCASE` to the unique index in a migration:
  ```ruby
  add_index :roles, [:company_id, :title], unique: true, collation: :nocase
  ```
  Note: SQLite requires dropping and recreating the index; this cannot be done with a simple `ALTER INDEX`.
- In the skip-duplicate logic, strip and downcase both the template title and the lookup:
  ```ruby
  normalized = entry[:title].strip
  existing = company.roles.find_by("LOWER(TRIM(title)) = LOWER(?)", normalized)
  next if existing  # skip duplicate
  ```

**Detection:** `company.roles.group("LOWER(TRIM(title))").having("COUNT(*) > 1").count` returns non-empty results.

**Confidence:** HIGH -- SQLite binary collation is documented behavior. The existing `index_roles_on_company_id_and_title` unique index is case-sensitive (verified in schema.rb line 309).

---

### Pitfall 5: Template Applied Without Transaction -- Partial Hierarchy Left on Error

**What goes wrong:** The template creates 6 roles: CTO, Tech Lead, 3 Developers, QA Lead. The first 4 succeed. The 5th fails (e.g., a skill key referenced in the template does not exist, or a validation error occurs). Without a wrapping transaction, 4 roles exist in the org chart with no QA Lead. The template is "partially applied" -- the user sees an incomplete hierarchy with no clear way to "undo" it or "retry" just the failed parts.

**Why it happens:** Rails does not automatically wrap a service object's operations in a transaction. Each `Role.create!` is its own implicit transaction. If the service does not explicitly use `ActiveRecord::Base.transaction { ... }`, each creation is independent.

**Consequences:** Incomplete org chart. No easy rollback. The user must manually delete the partial roles and retry, but now the skip-duplicate logic sees the already-created roles and skips them, so re-applying the template only creates the missing ones -- IF the error is transient. If the error is permanent (e.g., missing skill key), re-applying still fails at the same point.

**Prevention:**
- Wrap the entire template application in a single transaction:
  ```ruby
  ActiveRecord::Base.transaction do
    # create all roles
    # assign all skills
    # if anything raises, entire template is rolled back
  end
  ```
- Use `create!` (with bang) inside the transaction so validation failures raise and trigger rollback.
- Return a result object indicating success/failure with details, rather than silently half-applying.
- Consider a dry-run mode that validates all entries before creating any, reporting all errors up front.

**Detection:** Template application returns success for some roles but not all. `company.roles.where(title: template_role_titles).count` is less than `template_role_titles.size`.

**Confidence:** HIGH -- Standard Rails transactional pattern. The existing `db/seeds.rb` correctly wraps everything in `ActiveRecord::Base.transaction` (line 9).

---

## Moderate Pitfalls

---

### Pitfall 6: Skill Keys in Template Do Not Exist in Company's Skill Library

**What goes wrong:** The template YAML references skill key `"infrastructure_management"` for a DevOps role. Company A was created before that skill was added to the default skills library (a new skill YAML file was added in a later release). Company A's skill library does not contain `"infrastructure_management"`. The template application silently creates the role without that skill, or raises an error depending on implementation.

**Why it happens:** Skills are seeded per-company at company creation time via `Company#seed_default_skills!`. If new skills are added to `db/seeds/skills/` after the company was created, existing companies do not retroactively receive them. The template references skill keys that may not exist in all companies.

**Consequences:**
- Silent: Role is created but missing expected skills. The agent performs poorly because it lacks instructions for key capabilities.
- Loud: Template application fails entirely if the code does `Skill.find_by!(key:)` with a bang.
- Either way, the user has no visibility into which skills were skipped or missing.

**Prevention:**
- Before applying a template, verify all referenced skill keys exist in the target company:
  ```ruby
  required_keys = template.roles.flat_map(&:skill_keys).uniq
  existing_keys = company.skills.where(key: required_keys).pluck(:key)
  missing = required_keys - existing_keys
  if missing.any?
    # Option A: Auto-seed the missing skills from db/seeds/skills/
    # Option B: Return error listing missing skills
  end
  ```
- Option A is better UX: the template application service calls `company.seed_default_skills!` (which uses `find_or_create_by!`) before applying the template. This is idempotent and fills any gaps.
- Add a `Company#ensure_skills_current!` method that re-runs seeding for any missing builtin skills.

**Detection:** After template application, check `role.skills.count` for each created role versus the template's expected skill count.

**Confidence:** HIGH -- The `seed_default_skills!` method in Company uses `find_or_create_by!` (line 22), confirming it is designed to be re-runnable. New skills added to `db/seeds/skills/` are not automatically propagated to existing companies.

---

### Pitfall 7: Template Attach Point (CEO) Not Found or Ambiguous

**What goes wrong:** The template says "attach this department under the CEO role." The service looks up `company.roles.find_by(title: "CEO")`. But the company does not have a role titled "CEO" (they renamed it to "Founder" or "Managing Director"). The lookup returns nil. The template's root role (e.g., CTO) is created as a root node instead of nested under the CEO. Or worse, the service raises an error and the user gets a confusing message.

**Why it happens:** Templates assume a standard org chart structure. Real companies customize their hierarchies. The CEO title is not guaranteed to exist, and even if it does, there could be title variations.

**Consequences:** Template department is created as a disconnected subtree, floating in the org chart with no connection to the existing hierarchy. Or template application fails with an unhelpful error.

**Prevention:**
- Make the attach point an explicit parameter, not an assumption. The UI should let the user choose which existing role to attach the department under:
  ```ruby
  ApplyDepartmentTemplate.new(
    company: company,
    template_key: "engineering",
    attach_to: params[:parent_role_id]  # User selects this
  )
  ```
- Validate the attach point exists and belongs to the same company before starting template application.
- If no attach point is specified, create the department's root role as a root node and let the user drag it into place via the org chart UI.
- Never hard-code "CEO" as the default attach point in the template itself.

**Detection:** Template root roles appear at the top level of the org chart instead of nested under the expected parent.

**Confidence:** HIGH -- The existing seeds.rb hard-codes parent references as strings (line 56-68), which works for seeding but breaks for user-triggered template application.

---

### Pitfall 8: YAML Template References Create Ambiguous Title Lookups

**What goes wrong:** The template YAML uses title strings to reference parents within the template:

```yaml
roles:
  - title: "Tech Lead"
    parent: null  # attaches to the department root
  - title: "Senior Developer"
    parent: "Tech Lead"
  - title: "Developer"
    parent: "Tech Lead"
```

The parent resolution code does `created_roles.fetch(entry[:parent])` to look up already-created roles. But what if the company already has a role titled "Tech Lead" from a previous manual creation? The code must distinguish between "Tech Lead from THIS template application" and "Tech Lead that already existed." If skip-duplicate logic kicked in and reused the existing "Tech Lead" instead of creating a new one, the children should attach to that existing role. But if the existing "Tech Lead" is in a different part of the org chart (under CMO instead of CTO), the children end up in the wrong place.

**Why it happens:** Using title strings as both the skip-duplicate key AND the parent reference within the template creates ambiguity. "Tech Lead" could mean the one we just created/found, or one in a completely different department.

**Consequences:** Children attached to the wrong parent. Roles end up in incorrect departments. The org chart becomes structurally broken.

**Prevention:**
- When skip-duplicate finds an existing role, verify it is in the expected subtree (under the correct attach point) before reusing it as a parent.
- Maintain a local lookup hash that maps template-internal references to actual Role records (whether newly created or found via skip-duplicate):
  ```ruby
  resolved_roles = {}
  template.roles.each do |entry|
    existing = company.roles.find_by(title: entry[:title])
    if existing
      resolved_roles[entry[:title]] = existing
      next  # skip creation
    end
    parent = entry[:parent] ? resolved_roles.fetch(entry[:parent]) : attach_point
    resolved_roles[entry[:title]] = company.roles.create!(title: entry[:title], parent: parent, ...)
  end
  ```
- Consider whether "skip duplicate" should really reuse ANY existing role with that title, or only ones already in the expected position. A role titled "Developer" under CMO is probably not the same as "Developer" under CTO.
- If skip-duplicate is only meant to prevent re-application of the same template, add a `template_key` or `source` column to Role so you can scope duplicates to the same template origin.

**Detection:** After template application, verify the parent chain of each created role matches the template's hierarchy. `role.ancestors.map(&:title)` should match the expected path.

**Confidence:** HIGH -- Direct analysis of the skip-duplicate + parent-reference interaction in the template application flow.

---

### Pitfall 9: Re-Applying the Same Template Creates Duplicate Children

**What goes wrong:** User applies the "Engineering" template. Later, they delete one role from it and want to re-apply to restore it. The skip-duplicate logic sees "CTO" exists (skips it), "Tech Lead" exists (skips it), but "Developer" (which the user deleted) does not exist. "Developer" is recreated -- good. But the template defines THREE "Developer" roles. Since "Developer" is already taken as a title (uniqueness constraint on `[company_id, title]`), the second and third "Developer" fail with a uniqueness violation.

**Why it happens:** The template defines multiple roles with the same title (e.g., three Developers). Title uniqueness per company means only one "Developer" can exist. The template format cannot express "three instances of the Developer role" if titles must be unique.

**Consequences:** Template cannot be fully applied. The user expected 3 developers but gets 1. The error message ("Title already exists in this company") is confusing because the user did not manually create the duplicate.

**Prevention:**
- Template roles MUST have unique titles. Do not design templates with duplicate titles like three "Developer" roles.
- Instead, use distinct titles: "Developer 1", "Developer 2", "Developer 3" or "Backend Developer", "Frontend Developer", "Infrastructure Developer."
- Validate template YAML at load time: reject templates where any title appears more than once.
- Document this constraint clearly in the template YAML format specification.

**Detection:** Template application raises `ActiveRecord::RecordInvalid` with message "Title already exists in this company" on a role that the user did not manually create.

**Confidence:** HIGH -- The unique index `index_roles_on_company_id_and_title` enforces this at the database level. No workaround is possible without changing the schema.

---

### Pitfall 10: `Current.company` Not Set During Template Application from Non-Web Context

**What goes wrong:** Template application is triggered from a rake task, console, or background job. `Current.company` is nil. The `Tenantable` concern's `for_current_company` scope returns nothing. Any code that uses `Skill.for_current_company` or `Role.for_current_company` within the template application logic returns empty results. Skills are not found, roles are not found for duplicate checking, and the template is applied as if the company has no existing data.

**Why it happens:** `Current.company` is set by `SetCurrentCompany` controller concern during web requests. Service objects called from non-web contexts do not have this set. If the template application service internally uses `for_current_company` scopes (directly or through called methods), those scopes silently return empty results.

**Consequences:** Template creates duplicate roles (skip-duplicate check found nothing). Skill assignment fails silently (no skills found). In the worst case, if someone later adds `Current.company` scoping to a method that the template service calls, previously working code breaks.

**Prevention:**
- The template application service should NEVER rely on `Current.company`. Always scope through the explicit company association:
  ```ruby
  # BAD
  Skill.for_current_company.where(key: keys)

  # GOOD
  @company.skills.where(key: keys)
  ```
- Pass the company explicitly to every method. Do not reach for `Current.company` in any code called by the template service.
- If `Current.company` must be set (for callbacks like `create_config_version` that read it), set it explicitly at the start of the service:
  ```ruby
  def call
    Current.company = @company
    # ... template application ...
  ensure
    Current.company = nil
  end
  ```
- Test template application both from a controller context (Current.company set) and from an isolated unit test (Current.company nil).

**Detection:** Template application produces unexpected results when run from console or rake task but works from the UI. Skills not assigned. Duplicate roles created despite existing ones.

**Confidence:** HIGH -- `Current.company` usage is pervasive in the codebase (40+ references in tests and controllers). The `create_config_version` callback (line 39 in `config_versioned.rb`) explicitly falls back to `try(:company) || Current.company`.

---

## Minor Pitfalls

---

### Pitfall 11: YAML Template Loading Caches Stale Data in Development

**What goes wrong:** The developer edits a template YAML file. They reload the page and apply the template. The old version of the template is used because `YAML.load_file` result was cached in a class-level instance variable (similar to `Role.default_skills_config` which uses `@default_skills_config ||= ...`).

**Why it happens:** Class-level memoization with `||=` survives across requests in development when `config.cache_classes = false` is NOT properly clearing class-level state, or when using `eager_load = true`. The existing `default_skills_config` method on Role (line 46) has this exact pattern.

**Prevention:**
- In development, do not memoize template YAML at the class level. Use `Rails.env.development? ? YAML.load_file(path) : (@cache ||= YAML.load_file(path))`.
- Or use `Rails.application.config_for` which handles reloading.
- Or wrap in a `reloader` block that clears on file change.
- For the production case, class-level memoization is fine and desired for performance.

**Detection:** YAML file edits do not take effect until server restart.

**Confidence:** HIGH -- The existing `Role.default_skills_config` (line 46) uses `@default_skills_config ||=` which exhibits this exact caching behavior.

---

### Pitfall 12: Template YAML Uses Symbols Instead of Strings for Keys

**What goes wrong:** The template YAML is loaded with `YAML.load_file`. In Ruby 3.1+, `Psych 4.0` changed the default behavior: `YAML.load` no longer converts string keys to symbols and raises on certain types. Using `YAML.load_file` with `permitted_classes` or `YAML.safe_load_file` behaves differently from the old `YAML.load`. The template code accesses `entry[:title]` but the YAML returns `{"title" => "CTO"}`. The symbol key lookup returns nil. The role is created with a nil title and fails validation.

**Why it happens:** Ruby/Psych changed YAML loading defaults for security. Hash keys from YAML are strings by default. Code written expecting symbol keys breaks silently (nil instead of the expected value).

**Prevention:**
- Use `YAML.safe_load_file(path, permitted_classes: [])` and always access keys as strings: `entry["title"]`.
- Or use `entry.fetch("title")` which raises on missing keys rather than returning nil.
- Or use `with_indifferent_access`: `YAML.safe_load_file(path).deep_symbolize_keys` or `.with_indifferent_access`.
- Be consistent with the existing codebase pattern. The existing `Company.default_skill_definitions` (line 33) uses string keys: `data.fetch("key")`, `data.fetch("name")`.

**Detection:** Roles created with nil titles. `ArgumentError` or validation errors about missing required fields.

**Confidence:** HIGH -- Ruby 3.1 Psych 4.0 changes are well documented. The existing skill loading code uses string keys (`data.fetch("key")`), confirming the codebase convention.

---

### Pitfall 13: SQLite Busy Timeout During Large Template Application

**What goes wrong:** A template creates 8 roles, each with 3-5 skill assignments. That is 8 role inserts + up to 40 role_skill inserts + up to 8 config_version inserts = ~56 writes inside a single transaction. If another user is simultaneously doing anything that writes (creating a task, starting an agent run), the SQLite write lock contention can cause a `BusyException` if the busy_timeout is too short.

**Why it happens:** SQLite allows only one writer at a time. A single transaction holding the write lock for 56 inserts may take 50-200ms on a slow disk. If another writer's busy_timeout expires before the template transaction completes, the other writer gets `BusyException`.

**Prevention:**
- Keep the transaction as short as possible. Do all validation and data preparation BEFORE entering the transaction. Inside the transaction, only do inserts.
- Ensure `database.yml` has `timeout: 5000` or higher (5 seconds busy timeout).
- The template application transaction is short enough (~56 inserts) that this is unlikely to be a problem in practice with proper busy_timeout configuration. But it is worth verifying with a test that runs template application concurrently with other writes.
- If ConfigVersioned callbacks are suppressed (see Pitfall 2), the write count drops to ~48, further reducing lock hold time.

**Detection:** `SQLite3::BusyException` during template application, correlated with concurrent write activity.

**Confidence:** MEDIUM -- 56 inserts in a single transaction is well within SQLite's comfort zone with proper timeout configuration. This is a moderate risk, not a critical one. Elevated to a pitfall because the existing codebase has documented SQLite contention issues (Solid Queue #309).

---

### Pitfall 14: Template Defines Skills That Conflict with `default_skills.yml` Auto-Assignment

**What goes wrong:** The template YAML specifies that the "CTO" role should have skills `["code_review", "architecture_planning", "security_assessment"]`. The Role model has an `after_save :assign_default_skills` callback that triggers on first agent configuration. When an agent is later assigned to this CTO role, `assign_default_skills` runs and tries to add skills from `config/default_skills.yml` for the "CTO" title: `["code_review", "architecture_planning", "technical_strategy", "system_design", "security_assessment"]`. Three overlap with what the template already assigned. The callback's idempotency check (line 235: `existing_skill_ids`) prevents duplicate `RoleSkill` records, so no error occurs. But two additional skills (`technical_strategy`, `system_design`) are silently added that were NOT in the template.

**Why it happens:** Two separate systems assign skills to roles: (1) the template application, and (2) the `assign_default_skills` callback on first agent configuration. They are not coordinated. The callback does not know the role was created from a template and may have intentionally excluded certain skills.

**Consequences:** Roles end up with more skills than the template intended. Not a critical issue since extra skills only provide additional capabilities, but it violates the principle of least surprise. Users who carefully curated the template's skill list will be confused by extra skills appearing.

**Prevention:**
- Document this behavior: template-assigned skills are the initial set, and agent configuration may add more from `default_skills.yml`.
- If template-assigned skills should be the ONLY skills, add a flag to Role (e.g., `skills_locked` or `template_applied`) that `assign_default_skills` checks before adding more.
- Or accept this as designed behavior: templates set a baseline, and the auto-assignment enriches it. This is the simpler approach and probably correct for this system.

**Detection:** Role has more skills than the template specified. Check after agent assignment: `role.skills.count > template_skill_count`.

**Confidence:** HIGH -- Direct analysis of the `assign_default_skills` callback (lines 230-240 in role.rb) and `default_skills.yml` configuration.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| YAML template format design | Duplicate titles in template (Pitfall 9) | Validate template uniqueness at load time before any creation |
| YAML template format design | Symbol vs string keys (Pitfall 12) | Use `YAML.safe_load_file` + string keys, matching existing convention |
| Template application service | Parent ordering (Pitfall 1) | Topological sort or two-pass creation from the first implementation |
| Template application service | No transaction wrapper (Pitfall 5) | Wrap in `ActiveRecord::Base.transaction` from the start |
| Template application service | `Current.company` not set (Pitfall 10) | Use explicit company param, never `Current.company` in service |
| Skill pre-assignment | Cross-tenant skill reference (Pitfall 3) | Always scope through `company.skills`, test with two companies |
| Skill pre-assignment | Missing skills in old companies (Pitfall 6) | Call `company.seed_default_skills!` before template application |
| Duplicate detection | Case-insensitive matching (Pitfall 4) | Use `COLLATE NOCASE` or `LOWER()` in duplicate lookup |
| Duplicate detection | Ambiguous title reuse (Pitfall 8) | Track resolved roles in local hash, verify parent chain |
| Config versioning | Callback noise during bulk creation (Pitfall 2) | Suppress or batch ConfigVersion records |
| Attach point selection | CEO not found (Pitfall 7) | Make attach point a user-selected parameter |
| Re-application | Partial re-apply after deletion (Pitfall 9) | Unique titles only; document re-application behavior |

---

## Sources

- [One Row, Many Threads: How to Avoid Database Duplicates in Rails -- Evil Martians](https://evilmartians.com/chronicles/one-row-many-threads-how-to-avoid-database-duplicates-in-rails-applications) -- MEDIUM confidence (race condition patterns)
- [Rails 6 adds create_or_find_by -- Saeloun Blog](https://blog.saeloun.com/2019/02/23/rails-6-adds-create-or-find-by/) -- HIGH confidence (Rails API documentation)
- [Understanding Race Conditions with Duplicate Unique Keys -- makandra](https://makandracards.com/makandra/13901-understanding-race-conditions-with-duplicate-unique-keys-in-rails) -- HIGH confidence (well-documented pattern)
- [SQLite Foreign Key Support -- sqlite.org](https://sqlite.org/foreignkeys.html) -- HIGH confidence (official docs, deferred constraints)
- [ActiveRecord Callbacks Considered Harmful -- reinteractive](https://reinteractive.com/articles/ActiveRecord-callbacks-considered-harmful) -- MEDIUM confidence (callback side effects during bulk operations)
- [Active Record Callbacks -- Rails Guides](https://edgeguides.rubyonrails.org/active_record_callbacks.html) -- HIGH confidence (official Rails docs)
- Director codebase analysis: `app/models/role.rb`, `app/models/skill.rb`, `app/models/role_skill.rb`, `app/models/company.rb`, `app/models/concerns/tree_hierarchy.rb`, `app/models/concerns/config_versioned.rb`, `app/models/concerns/tenantable.rb`, `db/schema.rb`, `db/seeds.rb`, `config/default_skills.yml` -- HIGH confidence (direct source code reading)
