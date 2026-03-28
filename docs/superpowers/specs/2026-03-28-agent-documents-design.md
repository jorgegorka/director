# Agent Documents — Sharable Business Logic

## Overview

Documents are company-scoped markdown content representing business logic, policies, guidelines, and knowledge. They can be created by both humans and agents, linked to skills, agents, and tasks to provide context for agent work.

## Data Model

### `documents` table

| Column | Type | Notes |
|--------|------|-------|
| id | integer | PK, auto-increment |
| company_id | integer | FK → companies (Tenantable) |
| title | string | Required |
| body | text | Markdown content, required |
| author_type | string | Polymorphic — "User" or "Agent" |
| author_id | integer | Creator |
| last_editor_type | string | Polymorphic — "User" or "Agent" |
| last_editor_id | integer | Last person/agent to edit |
| timestamps | | created_at, updated_at |

### `document_tags` table

| Column | Type | Notes |
|--------|------|-------|
| id | integer | PK |
| company_id | integer | FK → companies |
| name | string | Unique per company |
| timestamps | | |

### `document_taggings` join table

| Column | Type | Notes |
|--------|------|-------|
| document_id | integer | FK → documents |
| tag_id | integer | FK → document_tags |
| unique constraint | | (document_id, tag_id) |

### `skill_documents` join table

| Column | Type | Notes |
|--------|------|-------|
| skill_id | integer | FK → skills |
| document_id | integer | FK → documents |
| unique constraint | | (skill_id, document_id) |

### `agent_documents` join table

| Column | Type | Notes |
|--------|------|-------|
| agent_id | integer | FK → agents |
| document_id | integer | FK → documents |
| unique constraint | | (agent_id, document_id) |

### `task_documents` join table

| Column | Type | Notes |
|--------|------|-------|
| task_id | integer | FK → tasks |
| document_id | integer | FK → documents |
| unique constraint | | (task_id, document_id) |

## Linking Semantics

Three distinct linking mechanisms, each with different intent:

1. **Skill → Documents** (via `skill_documents`): Always-loaded knowledge bundled with the capability. When an agent has a skill, it automatically gets the skill's documents as core context. Example: a "refund processing" skill carries the refund policy document.

2. **Agent → Documents** (via `agent_documents`): Searchable reference material for the agent. Available on demand but not automatically injected into every run. Example: an agent has access to the employee handbook for occasional reference.

3. **Task → Documents** (via `task_documents`): Context provided for a specific piece of work. Automatically included when the agent works on that task. Both human-created and agent-created tasks can have documents attached.

## Models & Associations

### Document model

```ruby
# app/models/document.rb
class Document < ApplicationRecord
  include Tenantable, Auditable, Chronological

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

Renders markdown body via Commonmarker (same approach as Skill model).

### DocumentTag model

```ruby
# app/models/document_tag.rb
class DocumentTag < ApplicationRecord
  include Tenantable

  has_many :document_taggings, dependent: :destroy
  has_many :documents, through: :document_taggings

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
```

### Join models

`SkillDocument`, `AgentDocument`, `TaskDocument`, `DocumentTagging` — minimal models with two `belongs_to` associations and uniqueness validation on the pair.

### Additions to existing models

**Skill:**
```ruby
has_many :skill_documents, dependent: :destroy
has_many :documents, through: :skill_documents
```

**Agent:**
```ruby
has_many :agent_documents, dependent: :destroy
has_many :documents, through: :agent_documents

def all_documents
  skill_doc_ids = SkillDocument.where(skill_id: skill_ids).select(:document_id)

  Document.for_current_company
    .where(id: documents.select(:id))
    .or(Document.for_current_company.where(id: skill_doc_ids))
end
```

**Task:**
```ruby
has_many :task_documents, dependent: :destroy
has_many :documents, through: :task_documents
```

## Context Assembly for Agent Execution

The `ExecuteAgentJob` builds a context hash for the adapter. Documents are added as a new section, separated by category so adapters can present them appropriately:

```ruby
context = {
  # ... existing fields (run_id, trigger_type, task_id, etc.) ...
  documents: {
    skill_documents: [{ id:, title:, body:, tags: [...] }, ...],
    agent_documents: [{ id:, title:, body:, tags: [...] }, ...],
    task_documents:  [{ id:, title:, body:, tags: [...] }, ...]
  }
}
```

- `skill_documents`: from the agent's skills — core knowledge
- `agent_documents`: the agent's reference library
- `task_documents`: context for the specific task (only present for task-triggered runs)

## Agent-Created Documents

Agents can create documents during execution. A `CreateDocumentService` handles this:

- Accepts: `author` (Agent), `company`, `title`, `body`, `tag_names` (optional)
- Creates the document with `author_type: "Agent"`
- Finds or creates tags by name within the company
- No auto-linking — linking is always a deliberate, explicit action

The service is callable from anywhere. API integration for agent-created documents will be added in Phase 25 when the callback API (`POST /api/agent_runs/:id/result`) is built.

## Controllers & Routes

### DocumentsController

Standard RESTful CRUD scoped to company:

- `index` — list documents with tag filtering
- `show` — display document with rendered markdown, tags, and linked skills/agents/tasks
- `new` / `create` — create document (author = Current.user)
- `edit` / `update` — edit document (sets last_editor = Current.user)
- `destroy` — delete document and all its links

### DocumentTagsController

- `index` — list all tags for the company
- `create` / `destroy` — manage tags

### Linking controllers

Thin controllers for managing join records:

- `SkillDocumentsController` — `create` / `destroy` (nested under skills)
- `AgentDocumentsController` — `create` / `destroy` (nested under agents)
- `TaskDocumentsController` — `create` / `destroy` (nested under tasks)

### Routes

```ruby
resources :documents do
  resources :document_tags, only: [:create, :destroy], as: :tags
end
resources :document_tags, only: [:index]

resources :skills do
  resources :skill_documents, only: [:create, :destroy]
end
resources :agents do
  resources :agent_documents, only: [:create, :destroy]
end
resources :tasks do
  resources :task_documents, only: [:create, :destroy]
end
```

## Views & UI

### Documents pages

- **Index**: document list with title, author, tags (as chips), dates. Tag filtering. Search by title. "New Document" button.
- **Show**: title, rendered markdown body, author/last editor info, tag chips, "Linked to" section showing referencing skills/agents/tasks. Edit/Delete actions.
- **Form**: title field, markdown textarea for body, tag selector (add/remove existing, create new inline).

### Linking UI on existing pages

- **Skill show page**: "Documents" section listing linked documents with add/remove.
- **Agent show page**: "Documents" section listing linked documents with add/remove.
- **Task show/form**: "Documents" section with document picker for attaching documents.

All linking UIs use Turbo Frames for inline add/remove without full page reloads.

## Design Decisions

1. **No file uploads** — documents are pure markdown text, no ActiveStorage.
2. **No versioning** — light tracking only (last_editor_type/id + updated_at). No full version history.
3. **No auto-linking on creation** — documents are standalone after creation. Linking is always an explicit action by a human or agent.
4. **Always-loaded knowledge lives on skills, not agents** — if an agent should always have access to a document, attach it to the relevant skill. This avoids a "permanent vs searchable" distinction on agent-document links.
5. **Normalized tags** — `document_tags` + `document_taggings` tables instead of a JSON array, enabling querying and filtering.
6. **Separate join tables per relationship** — `skill_documents`, `agent_documents`, `task_documents` instead of a polymorphic join. Follows the existing `agent_skills` pattern.
7. **Context categories** — documents in the execution context are separated by source (skill/agent/task) so adapters can present them with appropriate framing.
