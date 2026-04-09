module Roles
  module Budgeting
    extend ActiveSupport::Concern

    included do
      attr_writer :preloaded_monthly_spend_cents

      scope :with_budget, -> { where.not(budget_cents: nil) }

      validates :budget_cents, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    end

    def reload(*)
      @monthly_spend_cents = nil
      remove_instance_variable(:@preloaded_monthly_spend_cents) if defined?(@preloaded_monthly_spend_cents)
      super
    end

    def budget_configured?
      budget_cents.present? && budget_cents > 0
    end

    def current_budget_period_start
      return nil unless budget_configured?
      (budget_period_start || Date.current.beginning_of_month)
    end

    def current_budget_period_end
      return nil unless budget_configured?
      current_budget_period_start.end_of_month
    end

    def monthly_spend_cents
      return 0 unless budget_configured?
      return @preloaded_monthly_spend_cents if defined?(@preloaded_monthly_spend_cents)

      @monthly_spend_cents ||= begin
        period_start = current_budget_period_start
        period_end = current_budget_period_end

        assigned_tasks
          .where.not(cost_cents: nil)
          .where(created_at: period_start.beginning_of_day..period_end.end_of_day)
          .sum(:cost_cents)
      end
    end

    def budget_remaining_cents
      return nil unless budget_configured?
      [ budget_cents - monthly_spend_cents, 0 ].max
    end

    def budget_utilization
      return 0.0 unless budget_configured?
      return 0.0 if budget_cents.zero?
      [ (monthly_spend_cents.to_f / budget_cents * 100), 100.0 ].min.round(1)
    end

    def budget_exhausted?
      budget_configured? && monthly_spend_cents >= budget_cents
    end

    def budget_alert_threshold?
      budget_configured? && budget_utilization >= 80.0
    end
  end
end
