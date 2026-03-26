module SetCurrentCompany
  extend ActiveSupport::Concern

  included do
    before_action :set_current_company
    helper_method :current_company
  end

  private

  def current_company
    Current.company
  end

  def set_current_company
    return unless Current.user

    if session[:company_id]
      Current.company = Current.user.companies.find_by(id: session[:company_id])
    end

    # If session company is invalid (user removed from it), clear it
    if session[:company_id] && Current.company.nil?
      session.delete(:company_id)
    end

    # If user has companies but none selected, auto-select first
    if Current.company.nil? && Current.user.companies.any?
      Current.company = Current.user.companies.first
      session[:company_id] = Current.company.id
    end
  end

  def require_company!
    unless Current.company
      redirect_to new_company_path, alert: "Please create a company to get started."
    end
  end
end
