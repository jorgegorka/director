class DocumentsController < ApplicationController
  before_action :require_company!
  before_action :set_document, only: [ :show, :edit, :update, :destroy ]

  def index
    @documents = Current.company.documents.includes(:author, :tags).order(:title)
    @documents = @documents.tagged_with(params[:tag]) if params[:tag].present?
    @documents = @documents.search_by_title(params[:q]) if params[:q].present?
    @tags = Current.company.document_tags.order(:name)
    @current_tag = params[:tag]
  end

  def show
    @linked_skills = @document.skills.order(:name)
    @linked_roles = @document.roles.order(:title)
    @linked_tasks = @document.tasks.order(:title)
  end

  def new
    @document = Current.company.documents.new
  end

  def create
    @document = Current.company.documents.new(document_params)
    @document.author = Current.user

    if @document.save
      redirect_to @document, notice: "'#{@document.title}' has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @document.last_editor = Current.user

    if @document.update(document_params)
      redirect_to @document, notice: "'#{@document.title}' has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @document.title
    @document.destroy
    redirect_to documents_path, notice: "'#{title}' has been deleted."
  end

  private

  def set_document
    @document = Current.company.documents.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :body, tag_ids: [])
  end
end
