class RoleDocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_role

  def create
    document = Current.company.documents.find(params[:document_id])
    @role.role_documents.find_or_create_by!(document: document)
    redirect_to @role, notice: "#{document.title} linked to #{@role.title}."
  end

  def destroy
    role_document = @role.role_documents.find(params[:id])
    doc_title = role_document.document.title
    role_document.destroy
    redirect_to @role, notice: "#{doc_title} removed from #{@role.title}."
  end

  private

  def set_role
    @role = Current.company.roles.find(params[:role_id])
  end
end
