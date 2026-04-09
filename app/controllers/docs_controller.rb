class DocsController < ApplicationController
  allow_unauthenticated_access
  layout "docs"

  PAGES = Dir[Rails.root.join("app/views/docs/*.html.erb")]
    .map { |f| File.basename(f, ".html.erb") }
    .reject { |f| f.start_with?("_") }
    .to_set
    .freeze

  def index
  end

  def show
    slug = params[:path].tr("-", "_")
    raise ActionController::RoutingError, "Not Found" unless PAGES.include?(slug)
    page = PAGES.find { |p| p == slug }
    render template: "docs/#{page}"
  end
end
