class AgentDocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_agent

  def create
    document = Current.company.documents.find(params[:document_id])
    @agent.agent_documents.find_or_create_by!(document: document)
    redirect_to @agent, notice: "#{document.title} linked to #{@agent.name}."
  end

  def destroy
    agent_document = @agent.agent_documents.find(params[:id])
    doc_title = agent_document.document.title
    agent_document.destroy
    redirect_to @agent, notice: "#{doc_title} removed from #{@agent.name}."
  end

  private

  def set_agent
    @agent = Current.company.agents.find(params[:agent_id])
  end
end
