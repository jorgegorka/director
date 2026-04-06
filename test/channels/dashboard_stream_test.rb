require "test_helper"

class DashboardStreamTest < ActiveSupport::TestCase
  test "stream name includes project id" do
    project = projects(:acme)
    stream_name = "dashboard_project_#{project.id}"
    assert_includes stream_name, project.id.to_s
  end

  test "stream name is unique per project" do
    acme_stream = "dashboard_project_#{projects(:acme).id}"
    widgets_stream = "dashboard_project_#{projects(:widgets).id}"
    assert_not_equal acme_stream, widgets_stream
  end
end
