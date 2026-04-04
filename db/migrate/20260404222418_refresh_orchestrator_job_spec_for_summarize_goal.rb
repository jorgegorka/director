class RefreshOrchestratorJobSpecForSummarizeGoal < ActiveRecord::Migration[8.1]
  # The Orchestrator category's job_spec predated the `summarize_goal`
  # specialist. It still listed only three specialists and never told the
  # orchestrator how to react to the `goal_completed` hint returned from
  # `submit_review_decision`. Without that guidance the orchestrator has no
  # idea the summary specialist exists, so completed goals silently ship
  # with no outcome note for the user.
  #
  # This migration rewrites existing Orchestrator RoleCategory rows in place
  # -- but only when the stored job_spec still matches the previous
  # three-specialist wording. Rows already updated (or customized by users)
  # are left alone. Canonical text comes from db/seeds/role_categories.yml
  # at migration time so this stays in sync with whatever seeds say.

  LEGACY_MARKER = "Three of your MCP tools are **specialists**".freeze

  def up
    RoleCategory.reset_default_definitions! if RoleCategory.respond_to?(:reset_default_definitions!)
    definition = RoleCategory.default_definitions.find { |d| d["name"] == "Orchestrator" }
    return unless definition

    new_job_spec = definition.fetch("job_spec")

    RoleCategory.where(name: "Orchestrator").find_each do |category|
      next unless category.job_spec.to_s.include?(LEGACY_MARKER)

      category.update_column(:job_spec, new_job_spec)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
