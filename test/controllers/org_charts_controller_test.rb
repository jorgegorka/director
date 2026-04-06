require "test_helper"

class OrgChartsControllerTest < ActionDispatch::IntegrationTest
  test "should redirect org_chart to roles" do
    get "/org_chart"
    assert_response :redirect
    assert_redirected_to "/roles"
  end
end
