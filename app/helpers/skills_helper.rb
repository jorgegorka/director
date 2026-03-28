module SkillsHelper
  SKILL_CATEGORIES = %w[leadership technical creative operations research].freeze

  def skill_category_options
    SKILL_CATEGORIES.map { |cat| [ cat.capitalize, cat ] }
  end

  def skill_category_badge(category)
    return "" if category.blank?
    tag.span(category.capitalize, class: "skill-category-badge skill-category-badge--#{category}")
  end
end
