require "test_helper"

class Companies::SwitchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should switch active company" do
    post company_switch_url(companies(:widgets))
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert_select "h1", "Widget Factory"
  end

  test "should not switch to company user does not belong to" do
    other_company = Company.create!(name: "Secret Corp")
    post company_switch_url(other_company)
    assert_redirected_to companies_url
  end

  test "should redirect unauthenticated user" do
    sign_out
    post company_switch_url(companies(:acme))
    assert_redirected_to new_session_url
  end
end
