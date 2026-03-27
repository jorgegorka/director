require "test_helper"

class OrgChartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
  end

  test "should show org chart page" do
    get org_chart_url
    assert_response :success
    assert_select "h1", "Org Chart"
  end

  test "should contain org chart container with data" do
    get org_chart_url
    assert_response :success
    assert_select "[data-controller='org-chart']"
    assert_select "[data-org-chart-roles-value]"
  end

  test "should include role data in JSON" do
    get org_chart_url
    assert_response :success
    assert_match "CEO", response.body
    assert_match "CTO", response.body
  end

  test "should not include roles from other companies" do
    get org_chart_url
    # Operations Lead belongs to widgets company, should not appear
    # Check the data attribute specifically
    assert_select "[data-org-chart-roles-value]" do |elements|
      refute_match(/Operations Lead/, elements.first["data-org-chart-roles-value"])
    end
  end

  test "should show empty state when no roles exist" do
    sign_in_as(@user)
    post company_switch_url(companies(:widgets))
    roles(:widgets_lead).destroy
    get org_chart_url
    assert_response :success
    assert_select ".org-chart-page__empty"
  end

  test "should redirect unauthenticated user" do
    sign_out
    get org_chart_url
    assert_redirected_to new_session_url
  end

  test "should redirect user without company" do
    user_without_company = User.create!(email_address: "lonely@example.com", password: "password", password_confirmation: "password")
    sign_in_as(user_without_company)
    get org_chart_url
    assert_redirected_to new_company_url
  end
end
