# Agent Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a document management system that lets users and agents create markdown documents, tag them, and link them to skills (always-loaded), agents (reference), and tasks (context).

**Architecture:** Four new models (`Document`, `DocumentTag`, `DocumentTagging`, plus three join models), a CRUD controller for documents, three thin linking controllers, a `CreateDocumentService` for agent-authored documents, and document context injection into `ExecuteAgentJob`. Views follow the existing skill/task page patterns.

**Tech Stack:** Rails 8, Minitest + fixtures, Hotwire (Turbo Frames for linking UIs), custom CSS (OKLCH, CSS layers), Commonmarker for markdown rendering.

---

## File Structure

### New files to create:

**Migrations:**
- `db/migrate/TIMESTAMP_create_documents.rb`
- `db/migrate/TIMESTAMP_create_document_tags.rb`
- `db/migrate/TIMESTAMP_create_document_taggings.rb`
- `db/migrate/TIMESTAMP_create_skill_documents.rb`
- `db/migrate/TIMESTAMP_create_agent_documents.rb`
- `db/migrate/TIMESTAMP_create_task_documents.rb`

**Models:**
- `app/models/document.rb`
- `app/models/document_tag.rb`
- `app/models/document_tagging.rb`
- `app/models/skill_document.rb`
- `app/models/agent_document.rb`
- `app/models/task_document.rb`

**Controllers:**
- `app/controllers/documents_controller.rb`
- `app/controllers/document_tags_controller.rb`
- `app/controllers/skill_documents_controller.rb`
- `app/controllers/agent_documents_controller.rb`
- `app/controllers/task_documents_controller.rb`

**Views:**
- `app/views/documents/index.html.erb`
- `app/views/documents/show.html.erb`
- `app/views/documents/new.html.erb`
- `app/views/documents/edit.html.erb`
- `app/views/documents/_form.html.erb`
- `app/views/documents/_document.html.erb`
- `app/views/documents/_document_picker.html.erb`

**Services:**
- `app/services/create_document_service.rb`

**Fixtures:**
- `test/fixtures/documents.yml`
- `test/fixtures/document_tags.yml`
- `test/fixtures/document_taggings.yml`
- `test/fixtures/skill_documents.yml`
- `test/fixtures/agent_documents.yml`
- `test/fixtures/task_documents.yml`

**Tests:**
- `test/models/document_test.rb`
- `test/models/document_tag_test.rb`
- `test/models/document_tagging_test.rb`
- `test/models/skill_document_test.rb`
- `test/models/agent_document_test.rb`
- `test/models/task_document_test.rb`
- `test/controllers/documents_controller_test.rb`
- `test/controllers/skill_documents_controller_test.rb`
- `test/controllers/agent_documents_controller_test.rb`
- `test/controllers/task_documents_controller_test.rb`
- `test/services/create_document_service_test.rb`

### Existing files to modify:

- `app/models/skill.rb` — add document associations
- `app/models/agent.rb` — add document associations + `all_documents` method
- `app/models/task.rb` — add document associations
- `app/jobs/execute_agent_job.rb` — inject documents into context
- `app/controllers/agents_controller.rb` — load documents in `show`
- `app/controllers/skills_controller.rb` — load documents in `show`
- `app/controllers/tasks_controller.rb` — load documents in `show`
- `app/views/agents/show.html.erb` — add documents section
- `app/views/skills/show.html.erb` — add documents section
- `app/views/tasks/show.html.erb` — add documents section
- `config/routes.rb` — add document routes

---

## Task 1: Database Migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_create_documents.rb`
- Create: `db/migrate/TIMESTAMP_create_document_tags.rb`
- Create: `db/migrate/TIMESTAMP_create_document_taggings.rb`
- Create: `db/migrate/TIMESTAMP_create_skill_documents.rb`
- Create: `db/migrate/TIMESTAMP_create_agent_documents.rb`
- Create: `db/migrate/TIMESTAMP_create_task_documents.rb`

- [ ] **Step 1: Generate the documents migration**

```bash
bin/rails generate migration CreateDocuments \
  company:references title:string body:text \
  author_type:string author_id:integer \
  last_editor_type:string last_editor_id:integer \
  --no-test-framework
```

Edit the generated migration to add `null: false` constraints and indexes:

```ruby
class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.references :company, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.string :author_type, null: false
      t.integer :author_id, null: false
      t.string :last_editor_type
      t.integer :last_editor_id

      t.timestamps
    end

    add_index :documents, [:author_type, :author_id]
    add_index :documents, [:last_editor_type, :last_editor_id]
  end
end
```

- [ ] **Step 2: Generate the document_tags migration**

```bash
bin/rails generate migration CreateDocumentTags \
  company:references name:string \
  --no-test-framework
```

Edit to add constraints:

```ruby
class CreateDocumentTags < ActiveRecord::Migration[8.0]
  def change
    create_table :document_tags do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :document_tags, [:company_id, :name], unique: true
  end
end
```

- [ ] **Step 3: Generate the document_taggings migration**

```bash
bin/rails generate migration CreateDocumentTaggings \
  document:references document_tag:references \
  --no-test-framework
```

Edit:

```ruby
class CreateDocumentTaggings < ActiveRecord::Migration[8.0]
  def change
    create_table :document_taggings do |t|
      t.references :document, null: false, foreign_key: true
      t.references :document_tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :document_taggings, [:document_id, :document_tag_id], unique: true
  end
end
```

- [ ] **Step 4: Generate the skill_documents migration**

```bash
bin/rails generate migration CreateSkillDocuments \
  skill:references document:references \
  --no-test-framework
```

Edit:

```ruby
class CreateSkillDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :skill_documents do |t|
      t.references :skill, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :skill_documents, [:skill_id, :document_id], unique: true
  end
end
```

- [ ] **Step 5: Generate the agent_documents migration**

```bash
bin/rails generate migration CreateAgentDocuments \
  agent:references document:references \
  --no-test-framework
```

Edit:

```ruby
class CreateAgentDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_documents do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :agent_documents, [:agent_id, :document_id], unique: true
  end
end
```

- [ ] **Step 6: Generate the task_documents migration**

```bash
bin/rails generate migration CreateTaskDocuments \
  task:references document:references \
  --no-test-framework
```

Edit:

```ruby
class CreateTaskDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :task_documents do |t|
      t.references :task, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :task_documents, [:task_id, :document_id], unique: true
  end
end
```

- [ ] **Step 7: Run migrations**

```bash
bin/rails db:migrate
```

Expected: All 6 migrations run successfully. `db/schema.rb` updated with new tables.

- [ ] **Step 8: Commit**

```bash
git add db/migrate/*_create_documents.rb db/migrate/*_create_document_tags.rb \
  db/migrate/*_create_document_taggings.rb db/migrate/*_create_skill_documents.rb \
  db/migrate/*_create_agent_documents.rb db/migrate/*_create_task_documents.rb \
  db/schema.rb
git commit -m "feat: add database tables for documents, tags, and linking"
```

---

## Task 2: Document Model + Tests

**Files:**
- Create: `app/models/document.rb`
- Create: `test/fixtures/documents.yml`
- Create: `test/models/document_test.rb`

- [ ] **Step 1: Create fixtures**

Create `test/fixtures/documents.yml`:

```yaml
acme_refund_policy:
  company: acme
  title: Refund Policy
  body: "# Refund Policy\n\nAll refunds must be processed within 30 days.\n\n## Eligibility\n- Item must be unused\n- Receipt required"
  author_type: User
  author_id: <%= ActiveRecord::FixtureSet.identify(:one) %>

acme_coding_standards:
  company: acme
  title: Coding Standards
  body: "# Coding Standards\n\nFollow these guidelines for all code changes.\n\n## Rules\n- Use descriptive variable names\n- Write tests first"
  author_type: User
  author_id: <%= ActiveRecord::FixtureSet.identify(:one) %>

acme_agent_created_doc:
  company: acme
  title: Process Documentation
  body: "# Discovered Process\n\nThis process was documented by an agent during task execution."
  author_type: Agent
  author_id: <%= ActiveRecord::FixtureSet.identify(:claude_agent) %>

widgets_doc:
  company: widgets
  title: Widget Specs
  body: "# Widget Specifications\n\nAll widgets must meet quality standards."
  author_type: User
  author_id: <%= ActiveRecord::FixtureSet.identify(:one) %>
```

- [ ] **Step 2: Write failing tests**

Create `test/models/document_test.rb`:

```ruby
require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @widgets = companies(:widgets)
    @user = users(:one)
    @document = documents(:acme_refund_policy)
  end

  # --- Validations ---

  test "valid with title, body, author, and company" do
    doc = Document.new(
      company: @company,
      title: "New Doc",
      body: "# Content",
      author: @user
    )
    assert doc.valid?
  end

  test "invalid without title" do
    doc = Document.new(company: @company, title: nil, body: "# Content", author: @user)
    assert_not doc.valid?
    assert_includes doc.errors[:title], "can't be blank"
  end

  test "invalid without body" do
    doc = Document.new(company: @company, title: "Test", body: nil, author: @user)
    assert_not doc.valid?
    assert_includes doc.errors[:body], "can't be blank"
  end

  test "invalid without author" do
    doc = Document.new(company: @company, title: "Test", body: "# Content")
    assert_not doc.valid?
    assert doc.errors[:author].any?
  end

  # --- Associations ---

  test "belongs to company via Tenantable" do
    assert_equal @company, @document.company
  end

  test "has polymorphic author" do
    assert_equal @user, @document.author

    agent_doc = documents(:acme_agent_created_doc)
    assert_equal agents(:claude_agent), agent_doc.author
  end

  test "has many skills through skill_documents" do
    assert @document.respond_to?(:skills)
  end

  test "has many agents through agent_documents" do
    assert @document.respond_to?(:agents)
  end

  test "has many tasks through task_documents" do
    assert @document.respond_to?(:tasks)
  end

  test "has many tags through document_taggings" do
    assert @document.respond_to?(:tags)
  end

  # --- Scopes ---

  test "for_current_company scopes to Current.company" do
    Current.company = @company
    docs = Document.for_current_company
    assert_includes docs, documents(:acme_refund_policy)
    assert_not_includes docs, documents(:widgets_doc)
  end

  test "tagged_with filters by tag name" do
    tag = document_tags(:acme_policy_tag)
    DocumentTagging.create!(document: @document, document_tag: tag)

    results = Document.tagged_with("policy")
    assert_includes results, @document
    assert_not_includes results, documents(:acme_coding_standards)
  end

  test "by_author filters by author" do
    user_docs = Document.by_author(@user)
    assert_includes user_docs, @document
    assert_not_includes user_docs, documents(:acme_agent_created_doc)
  end

  # --- Dependent destroy ---

  test "destroying document destroys skill_documents" do
    doc = documents(:acme_coding_standards)
    SkillDocument.create!(skill: skills(:acme_code_review), document: doc)

    assert_difference("SkillDocument.count", -1) do
      doc.destroy
    end
  end

  test "destroying document destroys agent_documents" do
    doc = documents(:acme_coding_standards)
    AgentDocument.create!(agent: agents(:claude_agent), document: doc)

    assert_difference("AgentDocument.count", -1) do
      doc.destroy
    end
  end

  test "destroying document destroys task_documents" do
    doc = documents(:acme_coding_standards)
    TaskDocument.create!(task: tasks(:design_homepage), document: doc)

    assert_difference("TaskDocument.count", -1) do
      doc.destroy
    end
  end

  test "destroying document destroys document_taggings" do
    tag = document_tags(:acme_policy_tag)
    DocumentTagging.create!(document: @document, document_tag: tag)

    assert_difference("DocumentTagging.count", -1) do
      @document.destroy
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bin/rails test test/models/document_test.rb
```

Expected: FAIL — `Document` model does not exist yet.

- [ ] **Step 4: Create the Document model**

Create `app/models/document.rb`:

```ruby
class Document < ApplicationRecord
  include Tenantable
  include Auditable
  include Chronological

  belongs_to :author, polymorphic: true
  belongs_to :last_editor, polymorphic: true, optional: true

  has_many :skill_documents, dependent: :destroy
  has_many :skills, through: :skill_documents

  has_many :agent_documents, dependent: :destroy
  has_many :agents, through: :agent_documents

  has_many :task_documents, dependent: :destroy
  has_many :tasks, through: :task_documents

  has_many :document_taggings, dependent: :destroy
  has_many :tags, through: :document_taggings, source: :document_tag

  validates :title, presence: true
  validates :body, presence: true

  scope :tagged_with, ->(tag_name) {
    joins(:tags).where(document_tags: { name: tag_name })
  }
  scope :by_author, ->(author) {
    where(author: author)
  }
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/models/document_test.rb
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/document.rb test/models/document_test.rb test/fixtures/documents.yml
git commit -m "feat: add Document model with validations and associations"
```

---

## Task 3: DocumentTag Model + Tests

**Files:**
- Create: `app/models/document_tag.rb`
- Create: `test/fixtures/document_tags.yml`
- Create: `test/models/document_tag_test.rb`

- [ ] **Step 1: Create fixtures**

Create `test/fixtures/document_tags.yml`:

```yaml
acme_policy_tag:
  company: acme
  name: policy

acme_technical_tag:
  company: acme
  name: technical

acme_process_tag:
  company: acme
  name: process

widgets_general_tag:
  company: widgets
  name: general
```

- [ ] **Step 2: Write failing tests**

Create `test/models/document_tag_test.rb`:

```ruby
require "test_helper"

class DocumentTagTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @widgets = companies(:widgets)
    @tag = document_tags(:acme_policy_tag)
  end

  test "valid with name and company" do
    tag = DocumentTag.new(company: @company, name: "new-tag")
    assert tag.valid?
  end

  test "invalid without name" do
    tag = DocumentTag.new(company: @company, name: nil)
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "invalid with duplicate name in same company" do
    tag = DocumentTag.new(company: @company, name: "policy")
    assert_not tag.valid?
    assert tag.errors[:name].any?
  end

  test "allows duplicate name across different companies" do
    tag = DocumentTag.new(company: @widgets, name: "policy")
    assert tag.valid?
  end

  test "belongs to company via Tenantable" do
    assert_equal @company, @tag.company
  end

  test "has many documents through document_taggings" do
    assert @tag.respond_to?(:documents)
  end

  test "for_current_company scopes to Current.company" do
    Current.company = @company
    tags = DocumentTag.for_current_company
    assert_includes tags, document_tags(:acme_policy_tag)
    assert_not_includes tags, document_tags(:widgets_general_tag)
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bin/rails test test/models/document_tag_test.rb
```

Expected: FAIL — `DocumentTag` model does not exist yet.

- [ ] **Step 4: Create the DocumentTag model**

Create `app/models/document_tag.rb`:

```ruby
class DocumentTag < ApplicationRecord
  include Tenantable

  has_many :document_taggings, dependent: :destroy
  has_many :documents, through: :document_taggings

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/models/document_tag_test.rb
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/document_tag.rb test/models/document_tag_test.rb test/fixtures/document_tags.yml
git commit -m "feat: add DocumentTag model with uniqueness per company"
```

---

## Task 4: DocumentTagging Join Model + Tests

**Files:**
- Create: `app/models/document_tagging.rb`
- Create: `test/fixtures/document_taggings.yml`
- Create: `test/models/document_tagging_test.rb`

- [ ] **Step 1: Create fixtures**

Create `test/fixtures/document_taggings.yml`:

```yaml
refund_policy_tagged_policy:
  document: acme_refund_policy
  document_tag: acme_policy_tag

coding_standards_tagged_technical:
  document: acme_coding_standards
  document_tag: acme_technical_tag
```

- [ ] **Step 2: Write failing tests**

Create `test/models/document_tagging_test.rb`:

```ruby
require "test_helper"

class DocumentTaggingTest < ActiveSupport::TestCase
  setup do
    @document = documents(:acme_refund_policy)
    @tag = document_tags(:acme_technical_tag)
  end

  test "valid with document and tag" do
    tagging = DocumentTagging.new(document: @document, document_tag: @tag)
    assert tagging.valid?
  end

  test "invalid with duplicate document and tag pair" do
    tagging = DocumentTagging.new(
      document: documents(:acme_refund_policy),
      document_tag: document_tags(:acme_policy_tag)
    )
    assert_not tagging.valid?
    assert tagging.errors[:document_tag_id].any?
  end

  test "allows same tag on different documents" do
    tagging = DocumentTagging.new(
      document: documents(:acme_coding_standards),
      document_tag: document_tags(:acme_policy_tag)
    )
    assert tagging.valid?
  end

  test "belongs to document" do
    tagging = document_taggings(:refund_policy_tagged_policy)
    assert_equal @document, tagging.document
  end

  test "belongs to document_tag" do
    tagging = document_taggings(:refund_policy_tagged_policy)
    assert_equal document_tags(:acme_policy_tag), tagging.document_tag
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bin/rails test test/models/document_tagging_test.rb
```

Expected: FAIL — `DocumentTagging` model does not exist yet.

- [ ] **Step 4: Create the DocumentTagging model**

Create `app/models/document_tagging.rb`:

```ruby
class DocumentTagging < ApplicationRecord
  belongs_to :document
  belongs_to :document_tag

  validates :document_tag_id, uniqueness: { scope: :document_id, message: "already applied to this document" }
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/models/document_tagging_test.rb
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/document_tagging.rb test/models/document_tagging_test.rb test/fixtures/document_taggings.yml
git commit -m "feat: add DocumentTagging join model"
```

---

## Task 5: SkillDocument Join Model + Tests

**Files:**
- Create: `app/models/skill_document.rb`
- Create: `test/fixtures/skill_documents.yml`
- Create: `test/models/skill_document_test.rb`
- Modify: `app/models/skill.rb`

- [ ] **Step 1: Create fixtures**

Create `test/fixtures/skill_documents.yml`:

```yaml
code_review_has_coding_standards:
  skill: acme_code_review
  document: acme_coding_standards
```

- [ ] **Step 2: Write failing tests**

Create `test/models/skill_document_test.rb`:

```ruby
require "test_helper"

class SkillDocumentTest < ActiveSupport::TestCase
  setup do
    @skill = skills(:acme_code_review)
    @document = documents(:acme_refund_policy)
    @widgets_document = documents(:widgets_doc)
  end

  test "valid with skill and document from same company" do
    sd = SkillDocument.new(skill: @skill, document: @document)
    assert sd.valid?
  end

  test "invalid with duplicate skill and document pair" do
    sd = SkillDocument.new(
      skill: skills(:acme_code_review),
      document: documents(:acme_coding_standards)
    )
    assert_not sd.valid?
    assert sd.errors[:document_id].any?
  end

  test "allows same document on different skills" do
    sd = SkillDocument.new(
      skill: skills(:acme_strategic_planning),
      document: documents(:acme_coding_standards)
    )
    assert sd.valid?
  end

  test "invalid when skill and document from different companies" do
    sd = SkillDocument.new(skill: @skill, document: @widgets_document)
    assert_not sd.valid?
    assert_includes sd.errors[:document], "must belong to the same company as the skill"
  end

  test "belongs to skill" do
    sd = skill_documents(:code_review_has_coding_standards)
    assert_equal skills(:acme_code_review), sd.skill
  end

  test "belongs to document" do
    sd = skill_documents(:code_review_has_coding_standards)
    assert_equal documents(:acme_coding_standards), sd.document
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bin/rails test test/models/skill_document_test.rb
```

Expected: FAIL — `SkillDocument` model does not exist yet.

- [ ] **Step 4: Create the SkillDocument model**

Create `app/models/skill_document.rb`:

```ruby
class SkillDocument < ApplicationRecord
  belongs_to :skill
  belongs_to :document

  validates :document_id, uniqueness: { scope: :skill_id, message: "already linked to this skill" }
  validate :document_belongs_to_same_company

  private

  def document_belongs_to_same_company
    if skill.present? && document.present? && document.company_id != skill.company_id
      errors.add(:document, "must belong to the same company as the skill")
    end
  end
end
```

- [ ] **Step 5: Add associations to Skill model**

In `app/models/skill.rb`, add after the `has_many :agents` line:

```ruby
has_many :skill_documents, dependent: :destroy, inverse_of: :skill
has_many :documents, through: :skill_documents
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bin/rails test test/models/skill_document_test.rb
```

Expected: All tests PASS.

- [ ] **Step 7: Run existing skill tests to verify no regressions**

```bash
bin/rails test test/models/skill_test.rb
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/models/skill_document.rb app/models/skill.rb \
  test/models/skill_document_test.rb test/fixtures/skill_documents.yml
git commit -m "feat: add SkillDocument join model for always-loaded knowledge"
```

---

## Task 6: AgentDocument Join Model + Tests

**Files:**
- Create: `app/models/agent_document.rb`
- Create: `test/fixtures/agent_documents.yml`
- Create: `test/models/agent_document_test.rb`
- Modify: `app/models/agent.rb`

- [ ] **Step 1: Create fixtures**

Create `test/fixtures/agent_documents.yml`:

```yaml
claude_has_refund_policy:
  agent: claude_agent
  document: acme_refund_policy
```

- [ ] **Step 2: Write failing tests**

Create `test/models/agent_document_test.rb`:

```ruby
require "test_helper"

class AgentDocumentTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:claude_agent)
    @document = documents(:acme_coding_standards)
    @widgets_document = documents(:widgets_doc)
  end

  test "valid with agent and document from same company" do
    ad = AgentDocument.new(agent: @agent, document: @document)
    assert ad.valid?
  end

  test "invalid with duplicate agent and document pair" do
    ad = AgentDocument.new(
      agent: agents(:claude_agent),
      document: documents(:acme_refund_policy)
    )
    assert_not ad.valid?
    assert ad.errors[:document_id].any?
  end

  test "allows same document on different agents" do
    ad = AgentDocument.new(
      agent: agents(:http_agent),
      document: documents(:acme_refund_policy)
    )
    assert ad.valid?
  end

  test "invalid when agent and document from different companies" do
    ad = AgentDocument.new(agent: @agent, document: @widgets_document)
    assert_not ad.valid?
    assert_includes ad.errors[:document], "must belong to the same company as the agent"
  end

  test "belongs to agent" do
    ad = agent_documents(:claude_has_refund_policy)
    assert_equal agents(:claude_agent), ad.agent
  end

  test "belongs to document" do
    ad = agent_documents(:claude_has_refund_policy)
    assert_equal documents(:acme_refund_policy), ad.document
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bin/rails test test/models/agent_document_test.rb
```

Expected: FAIL — `AgentDocument` model does not exist yet.

- [ ] **Step 4: Create the AgentDocument model**

Create `app/models/agent_document.rb`:

```ruby
class AgentDocument < ApplicationRecord
  belongs_to :agent
  belongs_to :document

  validates :document_id, uniqueness: { scope: :agent_id, message: "already linked to this agent" }
  validate :document_belongs_to_same_company

  private

  def document_belongs_to_same_company
    if agent.present? && document.present? && document.company_id != agent.company_id
      errors.add(:document, "must belong to the same company as the agent")
    end
  end
end
```

- [ ] **Step 5: Add associations and `all_documents` to Agent model**

In `app/models/agent.rb`, add after the `has_many :agent_runs` line:

```ruby
has_many :agent_documents, dependent: :destroy, inverse_of: :agent
has_many :documents, through: :agent_documents
```

Add a public method after `latest_session_id`:

```ruby
def all_documents
  skill_doc_ids = SkillDocument.where(skill_id: skill_ids).select(:document_id)

  Document.for_current_company
    .where(id: documents.select(:id))
    .or(Document.for_current_company.where(id: skill_doc_ids))
end
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bin/rails test test/models/agent_document_test.rb
```

Expected: All tests PASS.

- [ ] **Step 7: Run existing agent tests to verify no regressions**

```bash
bin/rails test test/models/agent_test.rb
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/models/agent_document.rb app/models/agent.rb \
  test/models/agent_document_test.rb test/fixtures/agent_documents.yml
git commit -m "feat: add AgentDocument join model with all_documents method"
```

---

## Task 7: TaskDocument Join Model + Tests

**Files:**
- Create: `app/models/task_document.rb`
- Create: `test/fixtures/task_documents.yml`
- Create: `test/models/task_document_test.rb`
- Modify: `app/models/task.rb`

- [ ] **Step 1: Create fixtures**

Create `test/fixtures/task_documents.yml`:

```yaml
homepage_has_coding_standards:
  task: design_homepage
  document: acme_coding_standards
```

- [ ] **Step 2: Write failing tests**

Create `test/models/task_document_test.rb`:

```ruby
require "test_helper"

class TaskDocumentTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:design_homepage)
    @document = documents(:acme_refund_policy)
    @widgets_document = documents(:widgets_doc)
  end

  test "valid with task and document from same company" do
    td = TaskDocument.new(task: @task, document: @document)
    assert td.valid?
  end

  test "invalid with duplicate task and document pair" do
    td = TaskDocument.new(
      task: tasks(:design_homepage),
      document: documents(:acme_coding_standards)
    )
    assert_not td.valid?
    assert td.errors[:document_id].any?
  end

  test "allows same document on different tasks" do
    td = TaskDocument.new(
      task: tasks(:fix_login_bug),
      document: documents(:acme_coding_standards)
    )
    assert td.valid?
  end

  test "invalid when task and document from different companies" do
    td = TaskDocument.new(task: @task, document: @widgets_document)
    assert_not td.valid?
    assert_includes td.errors[:document], "must belong to the same company as the task"
  end

  test "belongs to task" do
    td = task_documents(:homepage_has_coding_standards)
    assert_equal tasks(:design_homepage), td.task
  end

  test "belongs to document" do
    td = task_documents(:homepage_has_coding_standards)
    assert_equal documents(:acme_coding_standards), td.document
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bin/rails test test/models/task_document_test.rb
```

Expected: FAIL — `TaskDocument` model does not exist yet.

- [ ] **Step 4: Create the TaskDocument model**

Create `app/models/task_document.rb`:

```ruby
class TaskDocument < ApplicationRecord
  belongs_to :task
  belongs_to :document

  validates :document_id, uniqueness: { scope: :task_id, message: "already linked to this task" }
  validate :document_belongs_to_same_company

  private

  def document_belongs_to_same_company
    if task.present? && document.present? && document.company_id != task.company_id
      errors.add(:document, "must belong to the same company as the task")
    end
  end
end
```

- [ ] **Step 5: Add associations to Task model**

In `app/models/task.rb`, add after the `has_many :agent_runs` line:

```ruby
has_many :task_documents, dependent: :destroy
has_many :documents, through: :task_documents
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bin/rails test test/models/task_document_test.rb
```

Expected: All tests PASS.

- [ ] **Step 7: Run existing task tests to verify no regressions**

```bash
bin/rails test test/models/task_test.rb
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/models/task_document.rb app/models/task.rb \
  test/models/task_document_test.rb test/fixtures/task_documents.yml
git commit -m "feat: add TaskDocument join model for task context"
```

---

## Task 8: Agent#all_documents Tests

**Files:**
- Modify: `test/models/agent_test.rb` (add new tests to existing file)

This tests the `all_documents` method added in Task 6.

- [ ] **Step 1: Write tests for all_documents**

Add the following tests to `test/models/agent_test.rb`:

```ruby
# --- all_documents ---

test "all_documents returns agent's directly linked documents" do
  Current.company = companies(:acme)
  agent = agents(:claude_agent)

  docs = agent.all_documents
  assert_includes docs, documents(:acme_refund_policy)
end

test "all_documents returns documents from agent's skills" do
  Current.company = companies(:acme)
  agent = agents(:claude_agent)

  # claude_agent has acme_code_review skill via fixture
  # acme_code_review has acme_coding_standards via skill_documents fixture
  docs = agent.all_documents
  assert_includes docs, documents(:acme_coding_standards)
end

test "all_documents does not return unlinked documents" do
  Current.company = companies(:acme)
  agent = agents(:claude_agent)

  docs = agent.all_documents
  assert_not_includes docs, documents(:acme_agent_created_doc)
end

test "all_documents does not return documents from other companies" do
  Current.company = companies(:acme)
  agent = agents(:claude_agent)

  docs = agent.all_documents
  assert_not_includes docs, documents(:widgets_doc)
end

test "all_documents does not duplicate documents linked both directly and via skill" do
  Current.company = companies(:acme)
  agent = agents(:claude_agent)

  # Link coding_standards directly to the agent too (it's already linked via skill)
  AgentDocument.find_or_create_by!(agent: agent, document: documents(:acme_coding_standards))

  docs = agent.all_documents
  coding_standards_count = docs.select { |d| d.id == documents(:acme_coding_standards).id }.count
  assert_equal 1, coding_standards_count
end
```

- [ ] **Step 2: Run the new tests**

```bash
bin/rails test test/models/agent_test.rb
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test/models/agent_test.rb
git commit -m "test: add all_documents method tests for Agent model"
```

---

## Task 9: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add document routes**

In `config/routes.rb`, add after the Skills routes block and before the Agents block:

```ruby
# Documents (scoped to active company via Current.company)
resources :documents
resources :document_tags, only: [:index, :create, :destroy]
```

Inside the existing `resources :skills` block, add:

```ruby
resources :skill_documents, only: [:create, :destroy]
```

Inside the existing `resources :agents` block, add:

```ruby
resources :agent_documents, only: [:create, :destroy]
```

Inside the existing `resources :tasks` block, add:

```ruby
resources :task_documents, only: [:create, :destroy]
```

The resulting agents block should look like:

```ruby
resources :agents do
  resources :agent_skills, only: [:create, :destroy]
  resources :agent_documents, only: [:create, :destroy]
  resources :heartbeats, only: [:index]
  resources :agent_hooks
  member do
    post :pause
    post :resume
    post :terminate
    post :approve
    post :reject
  end
end
```

- [ ] **Step 2: Verify routes**

```bash
bin/rails routes | grep document
```

Expected: Routes for documents (index, show, new, create, edit, update, destroy), document_tags (index, create, destroy), skill_documents, agent_documents, task_documents (create, destroy each).

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add routes for documents, tags, and linking"
```

---

## Task 10: DocumentsController + Tests

**Files:**
- Create: `app/controllers/documents_controller.rb`
- Create: `test/controllers/documents_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Create `test/controllers/documents_controller_test.rb`:

```ruby
require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @document = documents(:acme_refund_policy)
    @widgets_doc = documents(:widgets_doc)
  end

  # --- Index ---

  test "should get index" do
    get documents_url
    assert_response :success
  end

  test "should only show documents for current company" do
    get documents_url
    assert_response :success
    assert_select ".document-card__title", text: /Refund Policy/
    assert_select ".document-card__title", text: /Widget Specs/, count: 0
  end

  test "should filter by tag" do
    get documents_url(tag: "policy")
    assert_response :success
    assert_select ".document-card__title", text: /Refund Policy/
    assert_select ".document-card__title", text: /Coding Standards/, count: 0
  end

  test "should search by title" do
    get documents_url(q: "Refund")
    assert_response :success
    assert_select ".document-card__title", text: /Refund Policy/
    assert_select ".document-card__title", text: /Coding Standards/, count: 0
  end

  # --- Show ---

  test "should show document" do
    get document_url(@document)
    assert_response :success
    assert_select "h1", "Refund Policy"
  end

  test "should not show document from another company" do
    get document_url(@widgets_doc)
    assert_response :not_found
  end

  # --- New / Create ---

  test "should get new document form" do
    get new_document_url
    assert_response :success
    assert_select "form"
  end

  test "should create document" do
    assert_difference("Document.count", 1) do
      post documents_url, params: {
        document: {
          title: "New Document",
          body: "# New Document\n\nSome content."
        }
      }
    end
    doc = Document.order(:created_at).last
    assert_equal "New Document", doc.title
    assert_equal @user, doc.author
    assert_equal @company, doc.company
    assert_redirected_to document_url(doc)
  end

  test "should create document with tags" do
    tag = document_tags(:acme_policy_tag)
    post documents_url, params: {
      document: {
        title: "Tagged Doc",
        body: "# Content",
        tag_ids: [tag.id]
      }
    }
    doc = Document.order(:created_at).last
    assert_includes doc.tags, tag
  end

  test "should not create document without title" do
    assert_no_difference("Document.count") do
      post documents_url, params: {
        document: { title: "", body: "# Content" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create document without body" do
    assert_no_difference("Document.count") do
      post documents_url, params: {
        document: { title: "Test", body: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test "should get edit form" do
    get edit_document_url(@document)
    assert_response :success
    assert_select "form"
  end

  test "should update document" do
    patch document_url(@document), params: {
      document: { title: "Updated Title", body: "# Updated\n\nNew body." }
    }
    assert_redirected_to document_url(@document)
    @document.reload
    assert_equal "Updated Title", @document.title
    assert_equal @user, @document.last_editor
  end

  test "should not update document with blank title" do
    patch document_url(@document), params: {
      document: { title: "" }
    }
    assert_response :unprocessable_entity
  end

  test "should not update document from another company" do
    patch document_url(@widgets_doc), params: {
      document: { title: "Hacked" }
    }
    assert_response :not_found
  end

  # --- Destroy ---

  test "should destroy document" do
    assert_difference("Document.count", -1) do
      delete document_url(@document)
    end
    assert_redirected_to documents_url
  end

  test "should not destroy document from another company" do
    assert_no_difference("Document.count") do
      delete document_url(@widgets_doc)
    end
    assert_response :not_found
  end

  # --- Auth ---

  test "should redirect unauthenticated user" do
    sign_out
    get documents_url
    assert_redirected_to new_session_url
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/documents_controller_test.rb
```

Expected: FAIL — controller does not exist yet.

- [ ] **Step 3: Create the DocumentsController**

Create `app/controllers/documents_controller.rb`:

```ruby
class DocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_document, only: [:show, :edit, :update, :destroy]

  def index
    @documents = Current.company.documents.includes(:author, :tags).order(:title)
    @documents = @documents.tagged_with(params[:tag]) if params[:tag].present?
    @documents = @documents.where("title LIKE ?", "%#{params[:q]}%") if params[:q].present?
    @tags = Current.company.document_tags.order(:name)
    @current_tag = params[:tag]
  end

  def show
    @linked_skills = @document.skills.order(:name)
    @linked_agents = @document.agents.order(:name)
    @linked_tasks = @document.tasks.order(:title)
  end

  def new
    @document = Current.company.documents.new
  end

  def create
    @document = Current.company.documents.new(document_params)
    @document.author = Current.user

    if @document.save
      redirect_to @document, notice: "'#{@document.title}' has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @document.last_editor = Current.user

    if @document.update(document_params)
      redirect_to @document, notice: "'#{@document.title}' has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @document.title
    @document.destroy
    redirect_to documents_path, notice: "'#{title}' has been deleted."
  end

  private

  def set_document
    @document = Current.company.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :body, tag_ids: [])
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/controllers/documents_controller_test.rb
```

Expected: Tests that check HTML selectors (`.document-card__title`) will fail because views don't exist yet. The CRUD/redirect/auth tests should pass. Proceed — views will be added in Task 13.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/documents_controller.rb test/controllers/documents_controller_test.rb
git commit -m "feat: add DocumentsController with CRUD actions"
```

---

## Task 11: Linking Controllers + Tests

**Files:**
- Create: `app/controllers/skill_documents_controller.rb`
- Create: `app/controllers/agent_documents_controller.rb`
- Create: `app/controllers/task_documents_controller.rb`
- Create: `test/controllers/skill_documents_controller_test.rb`
- Create: `test/controllers/agent_documents_controller_test.rb`
- Create: `test/controllers/task_documents_controller_test.rb`

- [ ] **Step 1: Write failing tests for SkillDocumentsController**

Create `test/controllers/skill_documents_controller_test.rb`:

```ruby
require "test_helper"

class SkillDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @skill = skills(:acme_code_review)
  end

  test "should link document to skill" do
    doc = documents(:acme_refund_policy)
    assert_difference("SkillDocument.count", 1) do
      post skill_skill_documents_url(@skill), params: { document_id: doc.id }
    end
    assert_redirected_to skill_url(@skill)
  end

  test "should not duplicate link" do
    doc = documents(:acme_coding_standards) # already linked via fixture
    assert_no_difference("SkillDocument.count") do
      post skill_skill_documents_url(@skill), params: { document_id: doc.id }
    end
    assert_redirected_to skill_url(@skill)
  end

  test "should unlink document from skill" do
    sd = skill_documents(:code_review_has_coding_standards)
    assert_difference("SkillDocument.count", -1) do
      delete skill_skill_document_url(@skill, sd)
    end
    assert_redirected_to skill_url(@skill)
  end
end
```

- [ ] **Step 2: Write failing tests for AgentDocumentsController**

Create `test/controllers/agent_documents_controller_test.rb`:

```ruby
require "test_helper"

class AgentDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @agent = agents(:claude_agent)
  end

  test "should link document to agent" do
    doc = documents(:acme_coding_standards)
    assert_difference("AgentDocument.count", 1) do
      post agent_agent_documents_url(@agent), params: { document_id: doc.id }
    end
    assert_redirected_to agent_url(@agent)
  end

  test "should not duplicate link" do
    doc = documents(:acme_refund_policy) # already linked via fixture
    assert_no_difference("AgentDocument.count") do
      post agent_agent_documents_url(@agent), params: { document_id: doc.id }
    end
    assert_redirected_to agent_url(@agent)
  end

  test "should unlink document from agent" do
    ad = agent_documents(:claude_has_refund_policy)
    assert_difference("AgentDocument.count", -1) do
      delete agent_agent_document_url(@agent, ad)
    end
    assert_redirected_to agent_url(@agent)
  end
end
```

- [ ] **Step 3: Write failing tests for TaskDocumentsController**

Create `test/controllers/task_documents_controller_test.rb`:

```ruby
require "test_helper"

class TaskDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @task = tasks(:design_homepage)
  end

  test "should link document to task" do
    doc = documents(:acme_refund_policy)
    assert_difference("TaskDocument.count", 1) do
      post task_task_documents_url(@task), params: { document_id: doc.id }
    end
    assert_redirected_to task_url(@task)
  end

  test "should not duplicate link" do
    doc = documents(:acme_coding_standards) # already linked via fixture
    assert_no_difference("TaskDocument.count") do
      post task_task_documents_url(@task), params: { document_id: doc.id }
    end
    assert_redirected_to task_url(@task)
  end

  test "should unlink document from task" do
    td = task_documents(:homepage_has_coding_standards)
    assert_difference("TaskDocument.count", -1) do
      delete task_task_document_url(@task, td)
    end
    assert_redirected_to task_url(@task)
  end
end
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
bin/rails test test/controllers/skill_documents_controller_test.rb \
  test/controllers/agent_documents_controller_test.rb \
  test/controllers/task_documents_controller_test.rb
```

Expected: FAIL — controllers do not exist yet.

- [ ] **Step 5: Create SkillDocumentsController**

Create `app/controllers/skill_documents_controller.rb`:

```ruby
class SkillDocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_skill

  def create
    document = Current.company.documents.find(params[:document_id])
    @skill.skill_documents.find_or_create_by!(document: document)
    redirect_to @skill, notice: "#{document.title} linked to #{@skill.name}."
  end

  def destroy
    skill_document = @skill.skill_documents.find(params[:id])
    doc_title = skill_document.document.title
    skill_document.destroy
    redirect_to @skill, notice: "#{doc_title} removed from #{@skill.name}."
  end

  private

  def set_skill
    @skill = Current.company.skills.find(params[:skill_id])
  end
end
```

- [ ] **Step 6: Create AgentDocumentsController**

Create `app/controllers/agent_documents_controller.rb`:

```ruby
class AgentDocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_agent

  def create
    document = Current.company.documents.find(params[:document_id])
    @agent.agent_documents.find_or_create_by!(document: document)
    redirect_to @agent, notice: "#{document.title} linked to #{@agent.name}."
  end

  def destroy
    agent_document = @agent.agent_documents.find(params[:id])
    doc_title = agent_document.document.title
    agent_document.destroy
    redirect_to @agent, notice: "#{doc_title} removed from #{@agent.name}."
  end

  private

  def set_agent
    @agent = Current.company.agents.find(params[:agent_id])
  end
end
```

- [ ] **Step 7: Create TaskDocumentsController**

Create `app/controllers/task_documents_controller.rb`:

```ruby
class TaskDocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_task

  def create
    document = Current.company.documents.find(params[:document_id])
    @task.task_documents.find_or_create_by!(document: document)
    redirect_to @task, notice: "#{document.title} linked to this task."
  end

  def destroy
    task_document = @task.task_documents.find(params[:id])
    doc_title = task_document.document.title
    task_document.destroy
    redirect_to @task, notice: "#{doc_title} removed from this task."
  end

  private

  def set_task
    @task = Current.company.tasks.find(params[:task_id])
  end
end
```

- [ ] **Step 8: Run tests to verify they pass**

```bash
bin/rails test test/controllers/skill_documents_controller_test.rb \
  test/controllers/agent_documents_controller_test.rb \
  test/controllers/task_documents_controller_test.rb
```

Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/skill_documents_controller.rb \
  app/controllers/agent_documents_controller.rb \
  app/controllers/task_documents_controller.rb \
  test/controllers/skill_documents_controller_test.rb \
  test/controllers/agent_documents_controller_test.rb \
  test/controllers/task_documents_controller_test.rb
git commit -m "feat: add linking controllers for skill/agent/task documents"
```

---

## Task 12: DocumentTagsController + Tests

**Files:**
- Create: `app/controllers/document_tags_controller.rb`
- Create: `test/controllers/document_tags_controller_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/controllers/document_tags_controller_test.rb`:

```ruby
require "test_helper"

class DocumentTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
  end

  test "should get index" do
    get document_tags_url
    assert_response :success
  end

  test "should only show tags for current company" do
    get document_tags_url
    assert_response :success
    assert_select ".document-tag", text: /policy/
    assert_select ".document-tag", text: /general/, count: 0
  end

  test "should create tag" do
    assert_difference("DocumentTag.count", 1) do
      post document_tags_url, params: { document_tag: { name: "new-tag" } }
    end
    assert_redirected_to document_tags_url
  end

  test "should not create duplicate tag" do
    assert_no_difference("DocumentTag.count") do
      post document_tags_url, params: { document_tag: { name: "policy" } }
    end
    assert_response :unprocessable_entity
  end

  test "should destroy tag" do
    tag = document_tags(:acme_process_tag) # unused tag
    assert_difference("DocumentTag.count", -1) do
      delete document_tag_url(tag)
    end
    assert_redirected_to document_tags_url
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/document_tags_controller_test.rb
```

Expected: FAIL — controller does not exist yet.

- [ ] **Step 3: Create DocumentTagsController**

Create `app/controllers/document_tags_controller.rb`:

```ruby
class DocumentTagsController < ApplicationController
  before_action :require_company!

  def index
    @tags = Current.company.document_tags.order(:name)
  end

  def create
    @tag = Current.company.document_tags.new(tag_params)

    if @tag.save
      redirect_to document_tags_path, notice: "Tag '#{@tag.name}' created."
    else
      @tags = Current.company.document_tags.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    tag = Current.company.document_tags.find(params[:id])
    tag.destroy
    redirect_to document_tags_path, notice: "Tag '#{tag.name}' deleted."
  end

  private

  def tag_params
    params.require(:document_tag).permit(:name)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/controllers/document_tags_controller_test.rb
```

Expected: HTML selector tests may fail (views not yet created). CRUD/redirect tests should pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/document_tags_controller.rb test/controllers/document_tags_controller_test.rb
git commit -m "feat: add DocumentTagsController for tag management"
```

---

## Task 13: Document Views

**Files:**
- Create: `app/views/documents/index.html.erb`
- Create: `app/views/documents/show.html.erb`
- Create: `app/views/documents/new.html.erb`
- Create: `app/views/documents/edit.html.erb`
- Create: `app/views/documents/_form.html.erb`
- Create: `app/views/documents/_document.html.erb`
- Create: `app/views/documents/_document_picker.html.erb`
- Create: `app/views/document_tags/index.html.erb`

- [ ] **Step 1: Create document card partial**

Create `app/views/documents/_document.html.erb`:

```erb
<div class="document-card">
  <div class="document-card__main">
    <h3 class="document-card__title">
      <%= link_to document.title, document %>
    </h3>
    <% if document.tags.any? %>
      <div class="document-card__tags">
        <% document.tags.each do |tag| %>
          <span class="document-card__tag"><%= tag.name %></span>
        <% end %>
      </div>
    <% end %>
  </div>
  <div class="document-card__meta">
    <span class="document-card__author">
      by <%= document.author.try(:email_address) || document.author.try(:name) %>
    </span>
    <time class="document-card__date" datetime="<%= document.updated_at.iso8601 %>">
      <%= time_ago_in_words(document.updated_at) %> ago
    </time>
  </div>
</div>
```

- [ ] **Step 2: Create index page**

Create `app/views/documents/index.html.erb`:

```erb
<% content_for(:title, "Documents") %>

<section class="documents-page">
  <div class="documents-page__header">
    <h1>Documents</h1>
    <div class="documents-page__actions">
      <%= link_to "Manage Tags", document_tags_path, class: "btn btn--ghost btn--sm" %>
      <%= link_to "New Document", new_document_path, class: "btn btn--primary btn--sm" %>
    </div>
  </div>

  <% if @tags.any? %>
    <nav class="documents-page__filters">
      <%= link_to "All", documents_path, class: "filter-link #{"filter-link--active" unless @current_tag}" %>
      <% @tags.each do |tag| %>
        <%= link_to tag.name, documents_path(tag: tag.name),
              class: "filter-link #{"filter-link--active" if @current_tag == tag.name}" %>
      <% end %>
    </nav>
  <% end %>

  <%= form_with url: documents_path, method: :get, class: "documents-page__search" do |f| %>
    <%= f.search_field :q, value: params[:q], placeholder: "Search by title...", class: "form__input" %>
    <%= f.submit "Search", class: "btn btn--ghost btn--sm" %>
  <% end %>

  <% if @documents.any? %>
    <div class="documents-list">
      <% @documents.each do |document| %>
        <%= render partial: "documents/document", locals: { document: document } %>
      <% end %>
    </div>
  <% else %>
    <div class="documents-page__empty">
      <p>No documents yet. Create your first document to build your company's knowledge base.</p>
      <%= link_to "Create a document", new_document_path, class: "btn btn--primary" %>
    </div>
  <% end %>
</section>
```

- [ ] **Step 3: Create show page**

Create `app/views/documents/show.html.erb`:

```erb
<% content_for(:title, @document.title) %>

<section class="document-detail">
  <header class="document-detail__profile">
    <div class="document-detail__profile-main">
      <h1 class="document-detail__name"><%= @document.title %></h1>
      <div class="document-detail__meta">
        <span>by <%= @document.author.try(:email_address) || @document.author.try(:name) %></span>
        <% if @document.last_editor.present? %>
          <span>edited by <%= @document.last_editor.try(:email_address) || @document.last_editor.try(:name) %></span>
        <% end %>
        <time datetime="<%= @document.updated_at.iso8601 %>">
          Updated <%= time_ago_in_words(@document.updated_at) %> ago
        </time>
      </div>
      <% if @document.tags.any? %>
        <div class="document-detail__tags">
          <% @document.tags.each do |tag| %>
            <span class="document-card__tag"><%= tag.name %></span>
          <% end %>
        </div>
      <% end %>
    </div>
    <div class="document-detail__actions">
      <%= link_to "Edit", edit_document_path(@document), class: "btn btn--ghost btn--sm" %>
      <%= button_to "Delete", @document, method: :delete, class: "btn btn--ghost btn--sm document-detail__delete",
            data: { turbo_confirm: "Delete '#{@document.title}'? This will unlink it from all agents, skills, and tasks." } %>
    </div>
  </header>

  <div class="document-detail__grid">
    <div class="document-detail__primary">
      <div class="document-detail__card">
        <h2 class="document-detail__card-title">Content</h2>
        <div class="document-detail__markdown">
          <%= simple_format(@document.body) %>
        </div>
      </div>
    </div>

    <div class="document-detail__sidebar">
      <% if @linked_skills.any? %>
        <div class="document-detail__card">
          <h2 class="document-detail__card-title">Linked Skills (<%= @linked_skills.size %>)</h2>
          <ul class="document-detail__link-list">
            <% @linked_skills.each do |skill| %>
              <li><%= link_to skill.name, skill %></li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <% if @linked_agents.any? %>
        <div class="document-detail__card">
          <h2 class="document-detail__card-title">Linked Agents (<%= @linked_agents.size %>)</h2>
          <ul class="document-detail__link-list">
            <% @linked_agents.each do |agent| %>
              <li>
                <span class="role-card__agent-dot role-card__agent-dot--<%= agent.status %>"></span>
                <%= link_to agent.name, agent %>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <% if @linked_tasks.any? %>
        <div class="document-detail__card">
          <h2 class="document-detail__card-title">Linked Tasks (<%= @linked_tasks.size %>)</h2>
          <ul class="document-detail__link-list">
            <% @linked_tasks.each do |task| %>
              <li><%= link_to task.title, task %></li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
  </div>
</section>
```

- [ ] **Step 4: Create form partial**

Create `app/views/documents/_form.html.erb`:

```erb
<%= form_with(model: document, class: "form") do |f| %>
  <% if document.errors.any? %>
    <div class="form__errors" role="alert">
      <% document.errors.full_messages.each do |message| %>
        <p><%= message %></p>
      <% end %>
    </div>
  <% end %>

  <div class="form__field">
    <%= f.label :title, "Title" %>
    <%= f.text_field :title, autofocus: true, required: true, placeholder: "e.g. Refund Policy, Coding Standards" %>
  </div>

  <div class="form__field">
    <%= f.label :body, "Content (Markdown)" %>
    <%= f.text_area :body, rows: 16, required: true,
          placeholder: "# Document Title\n\n## Purpose\nDescribe the purpose...\n\n## Details\nAdd content here." %>
  </div>

  <% tags = Current.company.document_tags.order(:name) %>
  <% if tags.any? %>
    <fieldset class="form__field">
      <legend>Tags</legend>
      <div class="form__checkbox-group">
        <% tags.each do |tag| %>
          <label class="form__checkbox-label">
            <%= check_box_tag "document[tag_ids][]", tag.id, document.tag_ids.include?(tag.id) %>
            <%= tag.name %>
          </label>
        <% end %>
      </div>
      <p class="form__hint">Select tags to categorize this document. <%= link_to "Manage tags", document_tags_path %></p>
    </fieldset>
  <% end %>

  <div class="form__actions">
    <%= f.submit class: "btn btn--primary" %>
    <%= link_to "Cancel", document.persisted? ? document_path(document) : documents_path, class: "btn btn--ghost" %>
  </div>
<% end %>
```

- [ ] **Step 5: Create new and edit pages**

Create `app/views/documents/new.html.erb`:

```erb
<% content_for(:title, "New Document") %>

<section class="documents-page">
  <h1>New Document</h1>
  <%= render "form", document: @document %>
</section>
```

Create `app/views/documents/edit.html.erb`:

```erb
<% content_for(:title, "Edit #{@document.title}") %>

<section class="documents-page">
  <h1>Edit <%= @document.title %></h1>
  <%= render "form", document: @document %>
</section>
```

- [ ] **Step 6: Create document picker partial**

This is a reusable partial for linking documents from skill/agent/task pages.

Create `app/views/documents/_document_picker.html.erb`:

```erb
<%# locals: (linkable:, linked_documents:, link_path:, unlink_path_helper:) %>
<div class="document-picker">
  <% if linked_documents.any? %>
    <ul class="document-picker__list">
      <% linked_documents.each do |ld| %>
        <li class="document-picker__item">
          <%= link_to ld.document.title, ld.document, class: "document-picker__link" %>
          <%= button_to unlink_path_helper.call(linkable, ld),
                method: :delete,
                class: "document-picker__remove",
                title: "Remove #{ld.document.title}",
                data: { turbo_confirm: "Remove '#{ld.document.title}' from this #{linkable.class.name.downcase}?" } do %>
            &times;
          <% end %>
        </li>
      <% end %>
    </ul>
  <% end %>

  <% available_docs = Current.company.documents.where.not(id: linked_documents.map(&:document_id)).order(:title) %>
  <% if available_docs.any? %>
    <%= form_with url: link_path, method: :post, class: "document-picker__add" do |f| %>
      <%= f.select :document_id, available_docs.map { |d| [d.title, d.id] },
            { include_blank: "Link a document..." }, class: "form__select" %>
      <%= f.submit "Link", class: "btn btn--ghost btn--sm" %>
    <% end %>
  <% end %>

  <% if linked_documents.empty? && available_docs.empty? %>
    <p class="agent-detail__empty-note">No documents available. <%= link_to "Create one", new_document_path %></p>
  <% elsif linked_documents.empty? %>
    <p class="agent-detail__empty-note">No documents linked yet.</p>
  <% end %>
</div>
```

- [ ] **Step 7: Create document_tags index page**

Create `app/views/document_tags/index.html.erb`:

```erb
<% content_for(:title, "Document Tags") %>

<section class="documents-page">
  <div class="documents-page__header">
    <h1>Document Tags</h1>
    <%= link_to "Back to Documents", documents_path, class: "btn btn--ghost btn--sm" %>
  </div>

  <%= form_with model: DocumentTag.new, url: document_tags_path, class: "form form--inline" do |f| %>
    <div class="form__field">
      <%= f.text_field :name, placeholder: "New tag name...", required: true %>
    </div>
    <%= f.submit "Add Tag", class: "btn btn--primary btn--sm" %>
  <% end %>

  <% if @tags.any? %>
    <div class="document-tags-list">
      <% @tags.each do |tag| %>
        <div class="document-tag">
          <span class="document-tag__name"><%= tag.name %></span>
          <span class="document-tag__count"><%= tag.documents.count %></span>
          <%= button_to document_tag_path(tag), method: :delete,
                class: "document-tag__remove",
                title: "Delete tag '#{tag.name}'",
                data: { turbo_confirm: "Delete tag '#{tag.name}'? It will be removed from all documents." } do %>
            &times;
          <% end %>
        </div>
      <% end %>
    </div>
  <% else %>
    <p class="documents-page__empty">No tags yet. Add one above.</p>
  <% end %>
</section>
```

- [ ] **Step 8: Run all controller tests**

```bash
bin/rails test test/controllers/documents_controller_test.rb \
  test/controllers/document_tags_controller_test.rb
```

Expected: All tests PASS now that views exist.

- [ ] **Step 9: Commit**

```bash
git add app/views/documents/ app/views/document_tags/
git commit -m "feat: add document and tag views with picker partial"
```

---

## Task 14: Add Documents Section to Existing Pages

**Files:**
- Modify: `app/views/agents/show.html.erb`
- Modify: `app/views/skills/show.html.erb`
- Modify: `app/views/tasks/show.html.erb`
- Modify: `app/controllers/agents_controller.rb`
- Modify: `app/controllers/skills_controller.rb`
- Modify: `app/controllers/tasks_controller.rb`

- [ ] **Step 1: Add documents loading to AgentsController#show**

In `app/controllers/agents_controller.rb`, in the `show` action, add after `@agent_skills_by_skill_id`:

```ruby
@agent_document_links = @agent.agent_documents.includes(:document).order("documents.title")
```

- [ ] **Step 2: Add documents section to agent show page**

In `app/views/agents/show.html.erb`, add a new card inside the primary column (after the Skills card, before the closing `</div>` of `agent-detail__primary`):

```erb
<%# Documents %>
<div class="agent-detail__card">
  <h2 class="agent-detail__card-title">Documents</h2>
  <%= render "documents/document_picker",
        linkable: @agent,
        linked_documents: @agent_document_links,
        link_path: agent_agent_documents_path(@agent),
        unlink_path_helper: ->(agent, ad) { agent_agent_document_path(agent, ad) } %>
</div>
```

- [ ] **Step 3: Add documents loading to SkillsController#show**

In `app/controllers/skills_controller.rb`, in the `show` action, add after `@agents`:

```ruby
@skill_document_links = @skill.skill_documents.includes(:document).order("documents.title")
```

- [ ] **Step 4: Add documents section to skill show page**

In `app/views/skills/show.html.erb`, add a new card inside the sidebar column (after the "Assigned Agents" card):

```erb
<div class="skill-detail__card">
  <h2 class="skill-detail__card-title">Documents</h2>
  <%= render "documents/document_picker",
        linkable: @skill,
        linked_documents: @skill_document_links,
        link_path: skill_skill_documents_path(@skill),
        unlink_path_helper: ->(skill, sd) { skill_skill_document_path(skill, sd) } %>
</div>
```

- [ ] **Step 5: Add documents loading to TasksController#show**

In `app/controllers/tasks_controller.rb`, in the `show` action, add after `@message`:

```ruby
@task_document_links = @task.task_documents.includes(:document).order("documents.title")
```

- [ ] **Step 6: Add documents section to task show page**

In `app/views/tasks/show.html.erb`, add a new section after the "Details" section and before the "Workflow Actions" section:

```erb
<div class="task-detail__section">
  <h2>Documents</h2>
  <%= render "documents/document_picker",
        linkable: @task,
        linked_documents: @task_document_links,
        link_path: task_task_documents_path(@task),
        unlink_path_helper: ->(task, td) { task_task_document_path(task, td) } %>
</div>
```

- [ ] **Step 7: Run all controller tests to verify no regressions**

```bash
bin/rails test test/controllers/
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/views/agents/show.html.erb app/views/skills/show.html.erb \
  app/views/tasks/show.html.erb app/controllers/agents_controller.rb \
  app/controllers/skills_controller.rb app/controllers/tasks_controller.rb
git commit -m "feat: add documents section to agent, skill, and task show pages"
```

---

## Task 15: CreateDocumentService + Tests

**Files:**
- Create: `app/services/create_document_service.rb`
- Create: `test/services/create_document_service_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/services/create_document_service_test.rb`:

```ruby
require "test_helper"

class CreateDocumentServiceTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @agent = agents(:claude_agent)
    @user = users(:one)
  end

  test "creates document with agent author" do
    doc = CreateDocumentService.call(
      author: @agent,
      company: @company,
      title: "Agent Report",
      body: "# Report\n\nFindings here."
    )

    assert doc.persisted?
    assert_equal "Agent Report", doc.title
    assert_equal @agent, doc.author
    assert_equal @company, doc.company
  end

  test "creates document with user author" do
    doc = CreateDocumentService.call(
      author: @user,
      company: @company,
      title: "User Doc",
      body: "# User Doc\n\nContent."
    )

    assert doc.persisted?
    assert_equal @user, doc.author
  end

  test "creates and links tags by name" do
    doc = CreateDocumentService.call(
      author: @agent,
      company: @company,
      title: "Tagged Doc",
      body: "# Content",
      tag_names: ["policy", "new-tag"]
    )

    assert doc.persisted?
    assert_equal 2, doc.tags.count
    assert_includes doc.tags.pluck(:name), "policy"
    assert_includes doc.tags.pluck(:name), "new-tag"
  end

  test "finds existing tags instead of creating duplicates" do
    existing_tag = document_tags(:acme_policy_tag)

    assert_no_difference("DocumentTag.where(name: 'policy', company: @company).count") do
      CreateDocumentService.call(
        author: @agent,
        company: @company,
        title: "Doc with existing tag",
        body: "# Content",
        tag_names: ["policy"]
      )
    end
  end

  test "raises on invalid document" do
    assert_raises(ActiveRecord::RecordInvalid) do
      CreateDocumentService.call(
        author: @agent,
        company: @company,
        title: "",
        body: "# Content"
      )
    end
  end

  test "does not auto-link document to author agent" do
    doc = CreateDocumentService.call(
      author: @agent,
      company: @company,
      title: "Standalone Doc",
      body: "# Content"
    )

    assert_equal 0, doc.agent_documents.count
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/services/create_document_service_test.rb
```

Expected: FAIL — service does not exist yet.

- [ ] **Step 3: Create the service**

Create `app/services/create_document_service.rb`:

```ruby
class CreateDocumentService
  def self.call(author:, company:, title:, body:, tag_names: [])
    document = company.documents.create!(
      title: title,
      body: body,
      author: author
    )

    tag_names.each do |name|
      tag = company.document_tags.find_or_create_by!(name: name.strip.downcase)
      document.document_taggings.find_or_create_by!(document_tag: tag)
    end

    document
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/services/create_document_service_test.rb
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/create_document_service.rb test/services/create_document_service_test.rb
git commit -m "feat: add CreateDocumentService for agent and user document creation"
```

---

## Task 16: Document Context in ExecuteAgentJob + Tests

**Files:**
- Modify: `app/jobs/execute_agent_job.rb`
- Modify: `test/jobs/execute_agent_job_test.rb`

- [ ] **Step 1: Write failing tests**

Add the following tests to `test/jobs/execute_agent_job_test.rb`:

```ruby
test "build_context includes skill documents for the agent" do
  agent = agents(:claude_agent)
  # claude_agent has acme_code_review skill, which has acme_coding_standards document
  agent_run = AgentRun.create!(
    agent: agent,
    company: agent.company,
    status: :queued,
    trigger_type: :scheduled
  )

  job = ExecuteAgentJob.new
  ctx = job.send(:build_context, agent, agent_run)

  assert ctx.key?(:documents)
  assert ctx[:documents].key?(:skill_documents)
  skill_doc_titles = ctx[:documents][:skill_documents].map { |d| d[:title] }
  assert_includes skill_doc_titles, "Coding Standards"
end

test "build_context includes agent documents" do
  agent = agents(:claude_agent)
  # claude_agent has acme_refund_policy via agent_documents fixture
  agent_run = AgentRun.create!(
    agent: agent,
    company: agent.company,
    status: :queued,
    trigger_type: :scheduled
  )

  job = ExecuteAgentJob.new
  ctx = job.send(:build_context, agent, agent_run)

  agent_doc_titles = ctx[:documents][:agent_documents].map { |d| d[:title] }
  assert_includes agent_doc_titles, "Refund Policy"
end

test "build_context includes task documents when task present" do
  agent = agents(:claude_agent)
  task = tasks(:design_homepage)
  # design_homepage has acme_coding_standards via task_documents fixture
  agent_run = AgentRun.create!(
    agent: agent,
    company: agent.company,
    task: task,
    status: :queued,
    trigger_type: :task_assigned
  )

  job = ExecuteAgentJob.new
  ctx = job.send(:build_context, agent, agent_run)

  task_doc_titles = ctx[:documents][:task_documents].map { |d| d[:title] }
  assert_includes task_doc_titles, "Coding Standards"
end

test "build_context has empty task_documents when no task" do
  agent = agents(:claude_agent)
  agent_run = AgentRun.create!(
    agent: agent,
    company: agent.company,
    status: :queued,
    trigger_type: :scheduled
  )

  job = ExecuteAgentJob.new
  ctx = job.send(:build_context, agent, agent_run)

  assert_equal [], ctx[:documents][:task_documents]
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/jobs/execute_agent_job_test.rb
```

Expected: FAIL — `build_context` doesn't return documents yet.

- [ ] **Step 3: Update build_context in ExecuteAgentJob**

In `app/jobs/execute_agent_job.rb`, replace the `build_context` method:

```ruby
def build_context(agent, agent_run)
  ctx = {
    run_id: agent_run.id,
    trigger_type: agent_run.trigger_type
  }

  if agent_run.task_id.present?
    task = agent_run.task
    ctx[:task_id] = task.id
    ctx[:task_title] = task.title
    ctx[:task_description] = task.description
  end

  session_id = agent.latest_session_id
  ctx[:resume_session_id] = session_id if session_id.present?

  ctx[:documents] = build_document_context(agent, agent_run)

  ctx
end

def build_document_context(agent, agent_run)
  skill_doc_ids = SkillDocument.where(skill_id: agent.skill_ids).pluck(:document_id)
  agent_doc_ids = agent.agent_documents.pluck(:document_id)
  task_doc_ids = agent_run.task_id.present? ? TaskDocument.where(task_id: agent_run.task_id).pluck(:document_id) : []

  {
    skill_documents: serialize_documents(Document.where(id: skill_doc_ids)),
    agent_documents: serialize_documents(Document.where(id: agent_doc_ids)),
    task_documents: serialize_documents(Document.where(id: task_doc_ids))
  }
end

def serialize_documents(documents)
  documents.includes(:tags).map do |doc|
    {
      id: doc.id,
      title: doc.title,
      body: doc.body,
      tags: doc.tags.pluck(:name)
    }
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/jobs/execute_agent_job_test.rb
```

Expected: All tests PASS.

- [ ] **Step 5: Run full test suite to verify no regressions**

```bash
bin/rails test
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/jobs/execute_agent_job.rb test/jobs/execute_agent_job_test.rb
git commit -m "feat: inject document context into agent execution"
```

---

## Task 17: CSS Styles for Document Pages

**Files:**
- Modify: `app/assets/stylesheets/application.css`

- [ ] **Step 1: Add document styles**

Add to the end of `app/assets/stylesheets/application.css` (within the appropriate CSS layer if layers are used, otherwise at the end):

```css
/* ── Documents ── */

.documents-page__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-block-end: var(--space-4, 1rem);
}

.documents-page__actions {
  display: flex;
  gap: var(--space-2, 0.5rem);
}

.documents-page__filters {
  display: flex;
  gap: var(--space-2, 0.5rem);
  margin-block-end: var(--space-4, 1rem);
  flex-wrap: wrap;
}

.documents-page__search {
  display: flex;
  gap: var(--space-2, 0.5rem);
  margin-block-end: var(--space-4, 1rem);
  max-inline-size: 24rem;
}

.documents-page__empty {
  text-align: center;
  padding: var(--space-8, 2rem);
  color: var(--color-text-muted, oklch(0.65 0 0));
}

.documents-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-2, 0.5rem);
}

.document-card {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: var(--space-3, 0.75rem) var(--space-4, 1rem);
  background: var(--color-surface, oklch(0.99 0 0));
  border: 1px solid var(--color-border, oklch(0.9 0 0));
  border-radius: var(--radius-md, 0.5rem);
}

.document-card__title {
  font-size: var(--text-base, 1rem);
  margin: 0;
}

.document-card__title a {
  color: var(--color-text, oklch(0.2 0 0));
  text-decoration: none;
}

.document-card__title a:hover {
  text-decoration: underline;
}

.document-card__tags {
  display: flex;
  gap: var(--space-1, 0.25rem);
  margin-block-start: var(--space-1, 0.25rem);
}

.document-card__tag {
  font-size: var(--text-xs, 0.75rem);
  padding: 0.125rem 0.5rem;
  border-radius: var(--radius-full, 9999px);
  background: var(--color-surface-raised, oklch(0.95 0.01 250));
  color: var(--color-text-muted, oklch(0.5 0 0));
}

.document-card__meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: var(--space-1, 0.25rem);
  font-size: var(--text-sm, 0.875rem);
  color: var(--color-text-muted, oklch(0.65 0 0));
  white-space: nowrap;
}

/* Document detail */

.document-detail__profile {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-block-end: var(--space-6, 1.5rem);
}

.document-detail__name {
  margin: 0;
}

.document-detail__meta {
  display: flex;
  gap: var(--space-3, 0.75rem);
  font-size: var(--text-sm, 0.875rem);
  color: var(--color-text-muted, oklch(0.65 0 0));
  margin-block-start: var(--space-1, 0.25rem);
}

.document-detail__tags {
  display: flex;
  gap: var(--space-1, 0.25rem);
  margin-block-start: var(--space-2, 0.5rem);
}

.document-detail__actions {
  display: flex;
  gap: var(--space-2, 0.5rem);
}

.document-detail__grid {
  display: grid;
  grid-template-columns: 1fr 20rem;
  gap: var(--space-6, 1.5rem);
}

.document-detail__card {
  background: var(--color-surface, oklch(0.99 0 0));
  border: 1px solid var(--color-border, oklch(0.9 0 0));
  border-radius: var(--radius-md, 0.5rem);
  padding: var(--space-4, 1rem);
  margin-block-end: var(--space-4, 1rem);
}

.document-detail__card-title {
  font-size: var(--text-sm, 0.875rem);
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text-muted, oklch(0.5 0 0));
  margin-block-end: var(--space-3, 0.75rem);
}

.document-detail__markdown {
  line-height: 1.6;
}

.document-detail__link-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-2, 0.5rem);
}

/* Document picker */

.document-picker__list {
  list-style: none;
  padding: 0;
  margin: 0 0 var(--space-3, 0.75rem);
  display: flex;
  flex-direction: column;
  gap: var(--space-1, 0.25rem);
}

.document-picker__item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--space-1, 0.25rem) var(--space-2, 0.5rem);
  border-radius: var(--radius-sm, 0.25rem);
}

.document-picker__item:hover {
  background: var(--color-surface-raised, oklch(0.97 0 0));
}

.document-picker__remove {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-text-muted, oklch(0.65 0 0));
  font-size: var(--text-lg, 1.125rem);
  padding: 0 var(--space-1, 0.25rem);
  line-height: 1;
}

.document-picker__remove:hover {
  color: var(--color-danger, oklch(0.65 0.25 25));
}

.document-picker__add {
  display: flex;
  gap: var(--space-2, 0.5rem);
  align-items: center;
}

/* Document tags */

.document-tags-list {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2, 0.5rem);
  margin-block-start: var(--space-4, 1rem);
}

.document-tag {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2, 0.5rem);
  padding: var(--space-1, 0.25rem) var(--space-3, 0.75rem);
  background: var(--color-surface, oklch(0.99 0 0));
  border: 1px solid var(--color-border, oklch(0.9 0 0));
  border-radius: var(--radius-full, 9999px);
}

.document-tag__name {
  font-size: var(--text-sm, 0.875rem);
}

.document-tag__count {
  font-size: var(--text-xs, 0.75rem);
  color: var(--color-text-muted, oklch(0.65 0 0));
}

.document-tag__remove {
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-text-muted, oklch(0.65 0 0));
  font-size: var(--text-sm, 0.875rem);
  padding: 0;
  line-height: 1;
}

.document-tag__remove:hover {
  color: var(--color-danger, oklch(0.65 0.25 25));
}

.form--inline {
  display: flex;
  gap: var(--space-2, 0.5rem);
  align-items: flex-end;
  margin-block-end: var(--space-4, 1rem);
}

.form--inline .form__field {
  margin-block-end: 0;
}

.form__checkbox-group {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2, 0.5rem);
}

.form__checkbox-label {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1, 0.25rem);
  font-size: var(--text-sm, 0.875rem);
  cursor: pointer;
}
```

- [ ] **Step 2: Verify styles render correctly**

```bash
bin/dev
```

Visit `/documents` in the browser and verify the page renders with proper styling.

- [ ] **Step 3: Commit**

```bash
git add app/assets/stylesheets/application.css
git commit -m "feat: add CSS styles for document pages and picker"
```

---

## Task 18: Final Integration Test

- [ ] **Step 1: Run the full test suite**

```bash
bin/rails test
```

Expected: All tests PASS with zero failures.

- [ ] **Step 2: Run linting**

```bash
bin/rubocop
```

Expected: No new violations (or fix any that appear).

- [ ] **Step 3: Run security checks**

```bash
bin/brakeman --quiet --no-pager
```

Expected: No new security warnings.

- [ ] **Step 4: Commit any fixes**

If rubocop or brakeman flagged issues, fix them and commit:

```bash
git add -A
git commit -m "fix: address linting and security findings for documents feature"
```
