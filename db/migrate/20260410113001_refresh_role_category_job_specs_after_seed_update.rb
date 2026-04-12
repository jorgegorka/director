class RefreshRoleCategoryJobSpecsAfterSeedUpdate < ActiveRecord::Migration[8.1]
  # Rewrite RoleCategory job_spec rows that still reference the removed
  # Goal concepts (summarize_goal, goal_completed, list_my_goals, goal_id),
  # sourcing canonical text from the updated seeds. Rows without any legacy
  # marker are left alone so user customizations are preserved.

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
