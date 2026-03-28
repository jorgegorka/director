require "test_helper"

class SkillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @builtin_skill = skills(:acme_code_review)
    @custom_skill = skills(:acme_custom_skill)
    @leadership_skill = skills(:acme_strategic_planning)
    @widgets_skill = skills(:widgets_strategic_planning)
  end

  # --- Index ---

  test "should get index" do
    get skills_url
    assert_response :success
    assert_select ".skill-card", minimum: 3
  end

  test "should only show skills for current company" do
    get skills_url
    assert_response :success
    assert_select ".skill-card__title", text: /Code Review/
    # Widgets' strategic planning should not appear
    assert_select ".skill-card__description", text: /Widget-specific/, count: 0
  end

  test "should filter by category" do
    get skills_url(category: "technical")
    assert_response :success
    assert_select ".skill-card__title", text: /Code Review/
    # Leadership skill should not appear in technical filter
    assert_select ".skill-card__title", text: /Strategic Planning/, count: 0
  end

  test "should show all categories when no filter" do
    get skills_url
    assert_response :success
    # Both technical and leadership should be present
    assert_select ".skill-card", minimum: 2
  end

  test "should show filter navigation" do
    get skills_url
    assert_response :success
    assert_select ".filter-link", minimum: 2
    assert_select ".filter-link", text: "All"
  end

  test "should highlight active category filter" do
    get skills_url(category: "technical")
    assert_response :success
    assert_select ".filter-link--active", text: "Technical"
  end

  test "should show empty state for category with no skills" do
    get skills_url(category: "nonexistent")
    assert_response :success
    assert_select ".skills-page__empty"
  end

  # --- Show ---

  test "should show skill" do
    get skill_url(@builtin_skill)
    assert_response :success
    assert_select "h1", "Code Review"
  end

  test "should show skill markdown content" do
    get skill_url(@builtin_skill)
    assert_response :success
    assert_select ".skill-detail__markdown"
  end

  test "should show assigned agents on skill detail" do
    # claude_agent has acme_code_review via fixture
    get skill_url(@builtin_skill)
    assert_response :success
    assert_select ".skill-detail__agents-list li", minimum: 1
  end

  test "should show empty agents message when none assigned" do
    # acme_custom_skill has no agents assigned in fixtures
    get skill_url(@custom_skill)
    assert_response :success
    assert_select ".skill-detail__empty-note", text: /No agents/
  end

  test "should show category badge on skill detail" do
    get skill_url(@builtin_skill)
    assert_response :success
    assert_select ".skill-category-badge", text: /Technical/i
  end

  test "should show builtin label for builtin skill" do
    get skill_url(@builtin_skill)
    assert_response :success
    assert_select ".skill-card__builtin", text: /built-in/
  end

  test "should show custom label for custom skill" do
    get skill_url(@custom_skill)
    assert_response :success
    assert_select ".skill-card__custom", text: /custom/
  end

  test "should not show delete button for builtin skill" do
    get skill_url(@builtin_skill)
    assert_response :success
    assert_select ".skill-detail__delete", count: 0
  end

  test "should show delete button for custom skill" do
    get skill_url(@custom_skill)
    assert_response :success
    assert_select "form[action='#{skill_path(@custom_skill)}'] input[name='_method'][value='delete']"
  end

  test "should not show skill from another company" do
    get skill_url(@widgets_skill)
    assert_response :not_found
  end

  # --- New / Create ---

  test "should get new skill form" do
    get new_skill_url
    assert_response :success
    assert_select "form"
    assert_select "select[name='skill[category]']"
  end

  test "should create custom skill" do
    assert_difference("Skill.count", 1) do
      post skills_url, params: {
        skill: {
          key: "new_custom_skill",
          name: "New Custom Skill",
          description: "A test custom skill",
          markdown: "# New Custom Skill\n\nInstructions here.",
          category: "technical"
        }
      }
    end
    skill = Skill.order(:created_at).last
    assert_equal "new_custom_skill", skill.key
    assert_equal "New Custom Skill", skill.name
    assert_equal false, skill.builtin, "Created skills must be custom (builtin: false)"
    assert_equal @company, skill.company
    assert_equal "technical", skill.category
    assert_redirected_to skill_url(skill)
  end

  test "should create skill with builtin forced to false even if param sent" do
    post skills_url, params: {
      skill: {
        key: "sneaky_builtin",
        name: "Sneaky Builtin",
        markdown: "# Sneaky\n\nTrying to be builtin.",
        builtin: true
      }
    }
    skill = Skill.order(:created_at).last
    assert_equal false, skill.builtin, "Server must enforce builtin: false on create"
  end

  test "should not create skill without key" do
    assert_no_difference("Skill.count") do
      post skills_url, params: {
        skill: { key: "", name: "No Key Skill", markdown: "# Content" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create skill without name" do
    assert_no_difference("Skill.count") do
      post skills_url, params: {
        skill: { key: "no_name", name: "", markdown: "# Content" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create skill without markdown" do
    assert_no_difference("Skill.count") do
      post skills_url, params: {
        skill: { key: "no_md", name: "No Markdown", markdown: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create skill with duplicate key" do
    assert_no_difference("Skill.count") do
      post skills_url, params: {
        skill: { key: "code_review", name: "Duplicate Key", markdown: "# Dup" }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test "should get edit form for builtin skill" do
    get edit_skill_url(@builtin_skill)
    assert_response :success
    assert_select "form"
  end

  test "should get edit form for custom skill" do
    get edit_skill_url(@custom_skill)
    assert_response :success
    assert_select "form"
  end

  test "should update builtin skill content" do
    patch skill_url(@builtin_skill), params: {
      skill: { markdown: "# Updated Code Review\n\nNew instructions." }
    }
    assert_redirected_to skill_url(@builtin_skill)
    @builtin_skill.reload
    assert_equal "# Updated Code Review\n\nNew instructions.", @builtin_skill.markdown
    assert_equal true, @builtin_skill.builtin, "Builtin flag must not change on update"
  end

  test "should update custom skill" do
    patch skill_url(@custom_skill), params: {
      skill: { name: "Updated Custom Skill", description: "Updated description" }
    }
    assert_redirected_to skill_url(@custom_skill)
    @custom_skill.reload
    assert_equal "Updated Custom Skill", @custom_skill.name
  end

  test "should not update skill with blank name" do
    patch skill_url(@custom_skill), params: {
      skill: { name: "" }
    }
    assert_response :unprocessable_entity
  end

  test "should not update skill from another company" do
    patch skill_url(@widgets_skill), params: {
      skill: { name: "Hacked Skill" }
    }
    assert_response :not_found
  end

  # --- Destroy ---

  test "should destroy custom skill" do
    assert_difference("Skill.count", -1) do
      delete skill_url(@custom_skill)
    end
    assert_redirected_to skills_url
  end

  test "should not destroy builtin skill" do
    assert_no_difference("Skill.count") do
      delete skill_url(@builtin_skill)
    end
    assert_redirected_to skill_url(@builtin_skill)
    assert_equal "Built-in skills cannot be deleted.", flash[:alert]
  end

  test "should not destroy skill from another company" do
    assert_no_difference("Skill.count") do
      delete skill_url(@widgets_skill)
    end
    assert_response :not_found
  end

  # --- Auth / Scoping ---

  test "should redirect unauthenticated user" do
    sign_out
    get skills_url
    assert_redirected_to new_session_url
  end

  test "should redirect user without company" do
    user_without_company = User.create!(
      email_address: "skillless@example.com",
      password: "password",
      password_confirmation: "password"
    )
    sign_in_as(user_without_company)
    get skills_url
    assert_redirected_to new_company_url
  end
end
