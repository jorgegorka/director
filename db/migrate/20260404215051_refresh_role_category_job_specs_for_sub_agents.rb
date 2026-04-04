class RefreshRoleCategoryJobSpecsForSubAgents < ActiveRecord::Migration[8.1]
  # The Orchestrator/Planner category job_specs used to walk roles through
  # calling `create_task` with a hand-written title/description and
  # `update_task_status` with `completed`/`open` for reviews. Both of those
  # are incorrect (and the second is now a hard error) after the sub-agent
  # split.
  #
  # This migration rewrites existing RoleCategory rows in place -- but only
  # when the stored job_spec still matches the legacy text. We detect legacy
  # text via unique phrases that existed only in the old wording. Rows
  # customized by users won't contain those phrases, so they're left alone.
  #
  # The new canonical text is pulled from db/seeds/role_categories.yml at
  # migration time, so this migration stays in sync with whatever the seeds
  # file currently says.

  LEGACY_MARKERS = {
    "Orchestrator" => [
      "Delegate via `create_task`",
      "Reviewing submitted work",
      "Accept via `update_task_status`",
      "Approve with `update_task_status`"
    ],
    "Planner" => [
      "Accept via `update_task_status`",
      "Approve with `update_task_status`",
      "use `create_task` with `assignee_role_id`",
      "Call `create_task` with `assignee_role_id`"
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

        category.update_column(:job_spec, new_job_spec)
      end
    end
  end

  def down
    # Irreversible in a meaningful way -- we don't keep the old text anywhere
    # after running. The migration is safe to re-run if needed.
    raise ActiveRecord::IrreversibleMigration
  end
end
