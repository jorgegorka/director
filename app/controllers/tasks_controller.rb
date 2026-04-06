class TasksController < ApplicationController
  before_action :require_project!
  before_action :set_task, only: [ :show, :edit, :update, :destroy ]

  def index
    @tasks = Current.project.tasks
               .left_joins(:messages)
               .includes(:creator, :assignee, :parent_task)
               .select("tasks.*, COUNT(messages.id) AS messages_count")
               .group("tasks.id")
               .by_priority
  end

  def show
    @detail = Task::Detail.new(@task)
  end

  def new
    @task = Current.project.tasks.new(priority: :medium, goal_id: params[:goal_id])
  end

  def create
    @task = Current.project.tasks.new(task_params)

    if @task.save
      @task.record_audit_event!(
        actor: Current.user,
        action: "created",
        metadata: { title: @task.title, priority: @task.priority }
      )

      if @task.assignee.present?
        @task.record_audit_event!(
          actor: Current.user,
          action: "assigned",
          metadata: { assignee_id: @task.assignee_id, assignee_name: @task.assignee.title }
        )
      end

      redirect_to @task, notice: "Task '#{@task.title}' has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_status = @task.status
    old_assignee_id = @task.assignee_id

    if @task.update(task_params)
      if old_status != @task.status
        @task.record_audit_event!(
          actor: Current.user,
          action: "status_changed",
          metadata: { from: old_status, to: @task.status }
        )
      end

      if old_assignee_id != @task.assignee_id && @task.assignee_id.present?
        @task.record_audit_event!(
          actor: Current.user,
          action: "assigned",
          metadata: { assignee_id: @task.assignee_id, assignee_name: @task.assignee.title }
        )
      end

      redirect_to @task, notice: "Task '#{@task.title}' has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to tasks_path, notice: "Task '#{@task.title}' has been deleted."
  end

  private

  def set_task
    @task = Current.project.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :assignee_id, :creator_id, :due_at, :parent_task_id, :goal_id)
  end
end
