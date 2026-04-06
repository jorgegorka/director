class DocsController < ApplicationController
  allow_unauthenticated_access
  layout "docs"

  def index
  end

  def show
    render :index
  end
end
