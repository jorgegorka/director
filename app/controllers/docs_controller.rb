class DocsController < ApplicationController
  allow_unauthenticated_access
  layout "docs"

  def index
  end

  def show
    page = params[:path].tr("-", "_")
    render page
  end
end
