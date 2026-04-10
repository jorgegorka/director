class RefreshRoleCategoryJobSpecsAfterSeedUpdate < ActiveRecord::Migration[8.1]
  # The earlier 20260410112607 refresh ran before db/seeds/role_categories.yml
  # was updated to remove goal language, so it was a no-op. This migration
  # runs after the seed rewrite and forces the updated job_spec onto every
  # project's Orchestrator/Planner/Worker category whose stored spec still
  # mentions goals (the legacy markers).

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
