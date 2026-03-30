class TaskQuestionsController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def create
    assignee = @task.assignee
    unless assignee
      return respond_error(@task, "No assignee on this task.")
    end

    manager_role = assignee.manager_role
    unless manager_role
      return respond_error(@task, "No manager role available to answer questions.")
    end

    body = question_params[:body]
    if body.blank?
      return respond_error(@task, "Question body cannot be blank.")
    end

    message = @task.messages.create!(
      body: body,
      author: current_actor,
      message_type: :question
    )

    WakeRoleService.call(
      role: manager_role,
      trigger_type: :question_asked,
      trigger_source: "Message##{message.id}",
      context: {
        message_id: message.id,
        task_id: @task.id,
        asking_role_id: assignee.id
      }
    )

    @task.record_audit_event!(
      actor: current_actor,
      action: "question_asked",
      metadata: {
        message_id: message.id,
        asking_role_id: assignee.id,
        asking_role_title: assignee.title,
        manager_role_id: manager_role.id,
        manager_role_title: manager_role.title
      }
    )

    respond_to do |format|
      format.json { render json: { status: "ok", message_id: message.id, task_id: @task.id, message: "Question sent to #{manager_role.title}." }, status: :ok }
      format.html { redirect_to @task, notice: "Question sent to #{manager_role.title}." }
    end
  end

  private

  def question_params
    params.permit(:body)
  end
end
