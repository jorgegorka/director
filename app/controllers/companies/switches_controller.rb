class Companies::SwitchesController < ApplicationController
  def create
    company = Current.user.companies.find(params[:company_id])
    session[:company_id] = company.id
    redirect_to root_path, notice: "Switched to #{company.name}."
  rescue ActiveRecord::RecordNotFound
    redirect_to companies_path, alert: "Company not found."
  end
end
