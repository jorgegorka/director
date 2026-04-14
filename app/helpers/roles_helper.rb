module RolesHelper
  def role_status_badge(role)
    css_class = "status-badge status-badge--#{role.status}"
    tag.span(role.status.humanize, class: css_class)
  end

  def adapter_type_label(role)
    return "Vacant" unless role.adapter_type.present?
    AdapterRegistry.for(role.adapter_type).display_name
  end

  def adapter_type_options
    AdapterRegistry.adapter_types.map do |type|
      adapter_class = AdapterRegistry.for(type)
      [ adapter_class.display_name, type ]
    end
  end

  DEFAULT_CLAUDE_MODEL = "claude-sonnet-4-6".freeze

  CLAUDE_MODELS = [
    [ "Claude Opus 4.6", "claude-opus-4-6" ],
    [ "Claude Sonnet 4.6", "claude-sonnet-4-6" ],
    [ "Claude Haiku 4.5", "claude-haiku-4-5-20251001" ],
    [ "Claude Sonnet 4", "claude-sonnet-4-20250514" ],
    [ "Claude Opus 4", "claude-opus-4-20250514" ]
  ].freeze

  OPENCODE_MODELS = (CLAUDE_MODELS + [
    [ "Claude 3.7 Sonnet", "claude-3-7-sonnet-20250219" ],
    [ "GPT-4o", "gpt-4o" ],
    [ "GPT-4.1", "gpt-4.1" ],
    [ "Gemini 2.5 Pro", "gemini-2.5-pro" ],
    [ "GLM 4.7", "glm-4.7" ],
    [ "GLM 5", "glm-5" ]
  ]).freeze

  CODEX_MODELS = [
    [ "GPT-5 Codex", "gpt-5-codex" ],
    [ "GPT-5", "gpt-5" ],
    [ "o4-mini", "o4-mini" ],
    [ "GPT-4.1", "gpt-4.1" ]
  ].freeze

  DEFAULT_CODEX_MODEL = "gpt-5-codex".freeze

  def claude_model_options = CLAUDE_MODELS
  def opencode_model_options = OPENCODE_MODELS
  def codex_model_options = CODEX_MODELS
  def default_claude_model = DEFAULT_CLAUDE_MODEL
  def default_codex_model = DEFAULT_CODEX_MODEL

  def gate_description(action_type)
    descriptions = {
      "task_creation" => "Pause before creating new tasks",
      "task_delegation" => "Pause before delegating tasks to subordinates",
      "budget_spend" => "Pause before recording costs against budget",
      "status_change" => "Pause before changing task or role status",
      "escalation" => "Pause before escalating tasks to managers"
    }
    descriptions[action_type] || action_type.humanize
  end

  def gate_status_indicator(role)
    if role.has_any_gates?
      count = role.approval_gates.enabled.count
      tag.span("#{count} gate#{"s" if count != 1} active", class: "gate-indicator gate-indicator--active")
    else
      tag.span("No gates", class: "gate-indicator gate-indicator--none")
    end
  end
end
