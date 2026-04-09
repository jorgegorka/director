require "test_helper"

class Onboarding::TemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fresh_user = User.create!(
      email_address: "fresh@example.com",
      password: "securepassword",
      password_confirmation: "securepassword"
    )
    sign_in_as(@fresh_user)

    # Create project through onboarding step 1
    post onboarding_project_url, params: { project: { name: "Onboarding Test" } }
    @project = @fresh_user.projects.last
  end

  test "new shows template picker" do
    get new_onboarding_template_url
    assert_response :success
    assert_select ".template-picker__card", minimum: 2
  end

  test "create with template applies it and redirects to adapter step" do
    template = RoleTemplates::Registry.find("engineering")

    assert_difference "@project.roles.count", template.roles.size do
      post onboarding_template_url, params: { template_key: "engineering" }
    end

    assert_redirected_to new_onboarding_adapter_url
  end

  test "create with scratch skips adapter and redirects to completion" do
    assert_no_difference "@project.roles.count" do
      post onboarding_template_url, params: { template_key: "scratch" }
    end

    assert_redirected_to new_onboarding_completion_url
  end

  test "create with blank template_key treats as scratch" do
    post onboarding_template_url, params: { template_key: "" }
    assert_redirected_to new_onboarding_completion_url
  end

  test "redirects to project step if no onboarding project exists" do
    # Clear onboarding state
    delete_onboarding_state

    get new_onboarding_template_url
    assert_redirected_to new_onboarding_project_url
  end

  private

  def delete_onboarding_state
    # Sign in fresh to clear session
    fresh_user2 = User.create!(
      email_address: "fresh2@example.com",
      password: "securepassword",
      password_confirmation: "securepassword"
    )
    sign_in_as(fresh_user2)
  end
end
