class CompaniesController < ApplicationController
  def index
    @companies = Current.user.companies.includes(:memberships)
  end

  def new
    @company = Company.new
  end

  def create
    @company = Company.new(company_params)

    Company.transaction do
      @company.save!
      @company.memberships.create!(user: Current.user, role: :owner)
    end

    session[:company_id] = @company.id
    redirect_to root_path, notice: "#{@company.name} has been created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def emergency_stop
    company = Current.user.companies.find(params[:id])
    unless company == Current.company
      redirect_to companies_path, alert: "Cannot control agents for a company you are not viewing."
      return
    end

    paused_count = EmergencyStopService.call!(company: company, user: Current.user)
    redirect_to agents_path, notice: "Emergency stop activated. #{paused_count} agent(s) paused."
  end

  private

  def company_params
    params.require(:company).permit(:name)
  end
end
