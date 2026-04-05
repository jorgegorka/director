class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ home ]

  def home
    redirect_to dashboard_path and return if authenticated?
  end
end
