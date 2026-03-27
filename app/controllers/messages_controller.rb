class MessagesController < ApplicationController
  before_action :require_company!
  before_action :set_task

  def create
    @message = @task.messages.new(message_params)
    @message.author = Current.user

    if @message.save
      redirect_to task_path(@task, anchor: "message_#{@message.id}"), notice: "Message posted."
    else
      @messages = @task.messages.includes(:author, replies: :author).roots.chronological
      render "tasks/show", status: :unprocessable_entity
    end
  end

  private

  def set_task
    @task = Current.company.tasks.find(params[:task_id])
  end

  def message_params
    params.require(:message).permit(:body, :parent_id)
  end
end
