require "test_helper"

class DashboardStreamTest < ActiveSupport::TestCase
  test "stream name includes company id" do
    company = companies(:acme)
    stream_name = "dashboard_company_#{company.id}"
    assert_includes stream_name, company.id.to_s
  end

  test "stream name is unique per company" do
    acme_stream = "dashboard_company_#{companies(:acme).id}"
    widgets_stream = "dashboard_company_#{companies(:widgets).id}"
    assert_not_equal acme_stream, widgets_stream
  end
end
