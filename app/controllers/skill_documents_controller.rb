class SkillDocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_skill

  def create
    document = Current.company.documents.find(params[:document_id])
    @skill.skill_documents.find_or_create_by!(document: document)
    redirect_to @skill, notice: "#{document.title} linked to #{@skill.name}."
  end

  def destroy
    skill_document = @skill.skill_documents.find(params[:id])
    doc_title = skill_document.document.title
    skill_document.destroy
    redirect_to @skill, notice: "#{doc_title} removed from #{@skill.name}."
  end

  private

  def set_skill
    @skill = Current.company.skills.find(params[:skill_id])
  end
end
