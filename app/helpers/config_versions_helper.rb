module ConfigVersionsHelper
  def version_action_badge(action)
    css_class = case action
    when "create" then "version-badge--create"
    when "update" then "version-badge--update"
    when "rollback" then "version-badge--rollback"
    else "version-badge--default"
    end
    tag.span(action.capitalize, class: "version-badge #{css_class}")
  end

  def version_author_display(version)
    polymorphic_actor_label(version, type_method: :author_type, assoc: :author)
  end

  def version_diff_display(changeset)
    return "No changes recorded" if changeset.blank?

    items = changeset.reject { |k, _| k.start_with?("_") }.filter_map do |attr, values|
      next unless values.is_a?(Array) && values.length == 2

      content_tag(:div, class: "version-diff__item") do
        content_tag(:span, attr.humanize, class: "version-diff__attr") +
        content_tag(:span, "#{format_diff_value(values[0])} -> #{format_diff_value(values[1])}", class: "version-diff__change")
      end
    end
    safe_join(items)
  end

  def version_history_path_for(record)
    config_versions_path(type: record.class.name, record_id: record.id)
  end

  private

  def format_diff_value(value)
    case value
    when nil then "nil"
    when Integer then value.to_s
    when String then value.truncate(50)
    else value.to_s.truncate(50)
    end
  end
end
