class AuditEvent::Index
  attr_reader :company

  def initialize(company, filters = {})
    @company = company
    @filters = filters
  end

  def events
    @events ||= filtered_scope
                  .reverse_chronological
                  .includes(:actor, :auditable)
                  .limit(100)
  end

  def available_actions
    @available_actions ||= base_scope.distinct.pluck(:action).sort
  end

  def available_actor_types
    @available_actor_types ||= base_scope.distinct.pluck(:actor_type).compact.sort
  end

  def filtered?
    actor_type_filter.present? || action_filter.present? || start_date.present? || end_date.present?
  end

  def any_events?
    events.any?
  end

  def actor_type_filter
    @filters[:actor_type]
  end

  def action_filter
    @filters[:action_filter]
  end

  def start_date
    @filters[:start_date]
  end

  def end_date
    @filters[:end_date]
  end

  private

    def base_scope
      AuditEvent.for_company(company)
    end

    def filtered_scope
      scope = base_scope

      if actor_type_filter.present?
        scope = scope.for_actor_type(actor_type_filter)
      end

      if action_filter.present?
        scope = scope.for_action(action_filter)
      end

      if start_date.present? && end_date.present?
        parsed_start = Date.parse(start_date) rescue nil
        parsed_end = Date.parse(end_date) rescue nil
        if parsed_start && parsed_end
          scope = scope.for_date_range(parsed_start, parsed_end)
        end
      end

      scope
    end
end
