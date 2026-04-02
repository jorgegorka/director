class Dashboard::TaskBoard
  attr_reader :company

  def initialize(company)
    @company = company
  end

  def tasks_by_status
    @tasks_by_status ||= begin
      grouped = Task.statuses.keys.index_with { |_s| [] }
      all_tasks.each { |t| grouped[t.status] << t }
      grouped
    end
  end

  def all_tasks
    @all_tasks ||= company.tasks.includes(:assignee, :creator).order(priority: :desc, created_at: :desc)
  end
end
