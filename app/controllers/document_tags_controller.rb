class DocumentTagsController < ApplicationController
  before_action :require_company!

  def index
    @tags = Current.company.document_tags.order(:name)
  end

  def create
    @tag = Current.company.document_tags.new(tag_params)

    if @tag.save
      redirect_to document_tags_path, notice: "Tag '#{@tag.name}' created."
    else
      @tags = Current.company.document_tags.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    tag = Current.company.document_tags.find(params[:id])
    tag.destroy
    redirect_to document_tags_path, notice: "Tag '#{tag.name}' deleted."
  end

  private

  def tag_params
    params.require(:document_tag).permit(:name)
  end
end
