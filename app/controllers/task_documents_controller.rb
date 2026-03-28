class TaskDocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_task

  def create
    document = Current.company.documents.find(params[:document_id])
    @task.task_documents.find_or_create_by!(document: document)
    redirect_to @task, notice: "#{document.title} linked to this task."
  end

  def destroy
    task_document = @task.task_documents.find(params[:id])
    doc_title = task_document.document.title
    task_document.destroy
    redirect_to @task, notice: "#{doc_title} removed from this task."
  end

  private

  def set_task
    @task = Current.company.tasks.find(params[:task_id])
  end
end
