class RefreshRoleCategoryJobSpecsForAsyncSubAgents < ActiveRecord::Migration[8.1]
  # Sub-agent MCP tool calls (`create_task`, `review_task`, `hire_role`,
  # `summarize_task`) now return immediately with a queued invocation handle
  # and run the real work in a background job. The old synchronous contract
  # promised two things the new contract no longer delivers:
  #
  #   1. A `root_task_completed` hint returned from `review_task` that told
  #      the orchestrator to call `summarize_task` next. The chain now fires
  #      automatically from `SubAgentJob`; the orchestrator never sees a hint.
  #   2. An immediate result payload (e.g. the created task id). The queued
  #      response only carries a `sub_agent_invocation_id`.
  #
  # This migration rewrites existing Orchestrator / Planner RoleCategory rows
  # in place when they still carry the legacy wording. Rows customized by
  # users won't match the markers and are left alone.
  #
  # New canonical text is pulled from db/seeds/role_categories.yml at
  # migration time, so this migration stays in sync with the seeds file.

  LEGACY_MARKERS = {
    "Orchestrator" => [
      "root_task_completed: { id, title }",
      "if the specialist's response includes a `root_task_completed` hint"
    ],
    "Planner" => [
      "Three of your MCP tools are **specialists** -- `create_task`, `review_task`, and `hire_role`. Hand them the intent"
    ]
  }.freeze

  def up
    RoleCategory.reset_default_definitions! if RoleCategory.respond_to?(:reset_default_definitions!)
    new_definitions = RoleCategory.default_definitions.index_by { |d| d["name"] }

    LEGACY_MARKERS.each do |category_name, markers|
      definition = new_definitions[category_name]
      next unless definition

      new_job_spec = definition.fetch("job_spec")

      RoleCategory.where(name: category_name).find_each do |category|
        legacy = markers.any? { |m| category.job_spec.to_s.include?(m) }
        next unless legacy
        next if category.job_spec == new_job_spec # already up to date

        category.update_column(:job_spec, new_job_spec)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
