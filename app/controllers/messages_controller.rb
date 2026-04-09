class MessagesController < ApplicationController
  include AgentApiAuthenticatable
  before_action :set_task

  def create
    @message = @task.messages.new(message_params)
    @message.author = current_actor
  rescue ArgumentError => e
    respond_error(@task, e.message)
  else
    if @message.save
      respond_to do |format|
        format.json do
          render json: {
            id: @message.id,
            body: @message.body,
            message_type: @message.message_type,
            author: {
              id: @message.author.id,
              title: @message.author.try(:title) || @message.author.try(:email_address),
              type: @message.author.class.name
            },
            created_at: @message.created_at.iso8601
          }, status: :created
        end
        format.html { redirect_to task_path(@task, anchor: "message_#{@message.id}"), notice: "Message posted." }
      end
    else
      respond_to do |format|
        format.json { render json: { error: @message.errors.full_messages.first }, status: :unprocessable_entity }
        format.html do
          @detail = Task::Detail.new(@task)
          render "tasks/show", status: :unprocessable_entity
        end
      end
    end
  end

  private

  def message_params
    params.fetch(:message, {}).permit(:body, :parent_id, :message_type)
  end
end
