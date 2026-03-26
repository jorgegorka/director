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

  private

  def company_params
    params.require(:company).permit(:name)
  end
end
