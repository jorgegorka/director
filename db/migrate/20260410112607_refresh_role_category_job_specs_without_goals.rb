class RefreshRoleCategoryJobSpecsWithoutGoals < ActiveRecord::Migration[8.1]
  # Goals have been removed from the data model. Root tasks (tasks with
  # parent_task_id NULL) are the new top-level work unit. Role category
  # job_specs stored on existing projects still reference goals, the
  # summarize_goal specialist, and the goal_completed hint. This migration
  # rewrites those rows in place, sourcing canonical text from the updated
  # seeds at migration time.
  #
  # Rows whose job_spec no longer matches any legacy marker are left alone
  # so user customizations are preserved.

  LEGACY_MARKERS = [
    "summarize_goal",
    "goal_completed",
    "list_my_goals",
    "goal_id"
  ].freeze

  def up
    RoleCategory.reset_default_definitions! if RoleCategory.respond_to?(:reset_default_definitions!)
    new_definitions = RoleCategory.default_definitions.index_by { |d| d["name"] }

    new_definitions.each do |category_name, definition|
      new_job_spec = definition.fetch("job_spec")

      RoleCategory.where(name: category_name).find_each do |category|
        legacy = LEGACY_MARKERS.any? { |m| category.job_spec.to_s.include?(m) }
        next unless legacy

        category.update_column(:job_spec, new_job_spec)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
