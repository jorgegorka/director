class ApplicationController < ActionController::Base
  include Authentication
  include SetCurrentProject

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound do
    respond_to do |format|
      format.json { render json: { error: "Not found" }, status: :not_found }
      format.html { redirect_to root_path }
    end
  end

end
