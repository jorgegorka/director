module Tasks
  module ProjectScoping
    extend ActiveSupport::Concern

    included do
      validate :assignee_belongs_to_same_project
      validate :creator_belongs_to_same_project
      validate :parent_task_belongs_to_same_project
      validate :goal_belongs_to_same_project
    end

    private

    def assignee_belongs_to_same_project
      if assignee.present? && assignee.project_id != project_id
        errors.add(:assignee, "must belong to the same project")
      end
    end

    def creator_belongs_to_same_project
      if creator.present? && creator.project_id != project_id
        errors.add(:creator, "must belong to the same project")
      end
    end

    def parent_task_belongs_to_same_project
      if parent_task.present? && parent_task.project_id != project_id
        errors.add(:parent_task, "must belong to the same project")
      end
    end

    def goal_belongs_to_same_project
      if goal.present? && goal.project_id != project_id
        errors.add(:goal, "must belong to the same project")
      end
    end
  end
end
