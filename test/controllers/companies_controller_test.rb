require "test_helper"

class CompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "should get index with user's companies" do
    get companies_url
    assert_response :success
    assert_select ".company-card", count: 2  # user :one belongs to acme + widgets
  end

  test "should redirect unauthenticated user" do
    sign_out
    get companies_url
    assert_redirected_to new_session_url
  end

  test "should get new company form" do
    get new_company_url
    assert_response :success
    assert_select "form"
  end

  test "should create company and assign owner role" do
    assert_difference([ "Company.count", "Membership.count" ], 1) do
      post companies_url, params: { company: { name: "New AI Corp" } }
    end
    company = Company.order(:created_at).last
    assert_equal "New AI Corp", company.name
    membership = company.memberships.find_by(user: @user)
    assert membership.owner?
    assert_redirected_to root_url
  end

  test "should set session company_id after creation" do
    post companies_url, params: { company: { name: "Session Test Corp" } }
    follow_redirect! # root → pages#home redirects authenticated users to dashboard
    follow_redirect!
    assert_response :success
    # The dashboard should show the new company name
    assert_select "h1", "Session Test Corp"
  end

  test "should not create company with blank name" do
    assert_no_difference("Company.count") do
      post companies_url, params: { company: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "should get edit company form" do
    company = companies(:acme)
    get edit_company_url(company)
    assert_response :success
    assert_select "form"
  end

  test "should update company max_concurrent_agents" do
    company = companies(:acme)
    patch company_url(company), params: { company: { max_concurrent_agents: 3 } }
    assert_redirected_to companies_url
    assert_equal 3, company.reload.max_concurrent_agents
  end

  test "should not update company with invalid max_concurrent_agents" do
    company = companies(:acme)
    patch company_url(company), params: { company: { max_concurrent_agents: -1 } }
    assert_response :unprocessable_entity
  end

  test "should update company name" do
    company = companies(:acme)
    patch company_url(company), params: { company: { name: "Renamed Corp" } }
    assert_redirected_to companies_url
    assert_equal "Renamed Corp", company.reload.name
  end
end
