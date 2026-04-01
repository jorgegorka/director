module Roles
  module Hiring
    extend ActiveSupport::Concern

    class HiringError < StandardError; end

    included do
      has_many :pending_hires, dependent: :destroy
    end

    def department_template
      @department_template ||= begin
        root_role = find_department_root
        return nil if root_role.nil?

        RoleTemplates::Registry.all.find do |template|
          template.roles.first&.title == root_role.title
        end
      end
    end

    def hirable_roles
      template = department_template
      return [] if template.nil?

      my_title = title
      descendant_titles = collect_template_descendants(template, my_title)
      existing_titles = company.roles.where(title: descendant_titles).pluck(:title)

      template.roles.select { |tr| descendant_titles.include?(tr.title) && !existing_titles.include?(tr.title) }
    end

    def can_hire?(template_role_title)
      hirable_roles.any? { |tr| tr.title == template_role_title }
    end

    def hire!(template_role_title:, budget_cents:)
      validate_hire!(template_role_title, budget_cents)

      if auto_hire_enabled?
        template_role = find_template_role(template_role_title)
        create_hired_role(template_role, budget_cents)
      else
        request_hire_approval(template_role_title, budget_cents)
      end
    end

    def execute_hire!(pending_hire)
      template_role = find_template_role(pending_hire.template_role_title)
      create_hired_role(template_role, pending_hire.budget_cents)
    end

    private

    def find_department_root
      current = self
      template_root_titles = RoleTemplates::Registry.all.map { |t| t.roles.first&.title }.compact

      while current
        return current if template_root_titles.include?(current.title)
        current = current.parent
      end

      nil
    end

    def collect_template_descendants(template, ancestor_title)
      descendants = Set.new
      queue = [ ancestor_title ]

      while queue.any?
        current_title = queue.shift
        template.roles.each do |tr|
          if tr.parent == current_title && !descendants.include?(tr.title)
            descendants << tr.title
            queue << tr.title
          end
        end
      end

      descendants
    end

    def validate_hire!(template_role_title, budget_cents)
      unless can_hire?(template_role_title)
        if company.roles.exists?(title: template_role_title)
          raise HiringError, "Cannot hire #{template_role_title}: role already exists in this company"
        else
          raise HiringError, "Cannot hire #{template_role_title}: not a valid subordinate role for #{title}"
        end
      end

      if budget_configured? && budget_cents > self.budget_cents
        raise HiringError, "Insufficient budget: requested #{budget_cents} but your budget ceiling is #{self.budget_cents}"
      end
    end

    def find_template_role(template_role_title)
      template = department_template
      template.roles.find { |tr| tr.title == template_role_title }
    end

    def create_hired_role(template_role, hire_budget_cents)
      new_role = company.roles.create!(
        title: template_role.title,
        description: template_role.description,
        job_spec: template_role.job_spec,
        parent: self,
        adapter_type: adapter_type,
        adapter_config: adapter_config,

        budget_cents: hire_budget_cents,
        budget_period_start: Date.current.beginning_of_month,
        status: :idle
      )

      record_audit_event!(
        actor: self,
        action: "role_hired",
        metadata: {
          hired_role_id: new_role.id,
          hired_role_title: new_role.title,
          budget_cents: hire_budget_cents
        }
      )

      new_role
    end

    def request_hire_approval(template_role_title, budget_cents)
      pending_hire = pending_hires.create!(
        company: company,
        template_role_title: template_role_title,
        budget_cents: budget_cents
      )

      update!(
        status: :pending_approval,
        pause_reason: "Awaiting approval to hire #{template_role_title}"
      )

      notify_admins_of_hire_request(template_role_title, budget_cents)

      record_audit_event!(
        actor: self,
        action: "hire_requested",
        metadata: {
          requested_hire: template_role_title,
          budget_cents: budget_cents,
          pending_hire_id: pending_hire.id
        }
      )

      pending_hire
    end

    def notify_admins_of_hire_request(template_role_title, budget_cents)
      company.admin_recipients.each do |admin|
        Notification.create!(
          company: company,
          recipient: admin,
          actor: self,
          notifiable: self,
          action: "hire_approval_requested",
          metadata: {
            role_title: title,
            requested_hire: template_role_title,
            budget_cents: budget_cents
          }
        )
      end
    end
  end
end
