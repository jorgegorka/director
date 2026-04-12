class TasksController < ApplicationController
  before_action :require_project!
  before_action :require_roles!, only: [ :new, :create ]
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
    @task = Current.project.tasks.new(parent_task_id: params[:parent_task_id])
  end

  def create
    @task = Current.project.tasks.new(task_params)

    if @task.save
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
      if @task.status != old_status
        @task.record_audit_event!(actor: Current.user, action: "status_changed", metadata: { from: old_status, to: @task.status })
      end

      if @task.assignee_id != old_assignee_id && @task.assignee_id.present?
        @task.record_audit_event!(actor: Current.user, action: "assigned", metadata: { assignee_id: @task.assignee_id, assignee_name: @task.assignee.title })
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
    params.require(:task).permit(:title, :description, :status, :priority, :assignee_id, :creator_id, :due_at, :parent_task_id)
  end

  def require_roles!
    return if Current.project.roles.exists?

    redirect_to roles_path, notice: "You need to create at least one role before adding tasks."
  end
end
