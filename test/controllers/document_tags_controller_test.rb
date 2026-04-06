require "test_helper"

class DocumentTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
  end

  test "should get index" do
    get document_tags_url
    assert_response :success
  end

  test "should create tag" do
    assert_difference("DocumentTag.count", 1) do
      post document_tags_url, params: { document_tag: { name: "new-tag" } }
    end
    assert_redirected_to document_tags_url
  end

  test "should not create duplicate tag" do
    assert_no_difference("DocumentTag.count") do
      post document_tags_url, params: { document_tag: { name: "policy" } }
    end
    assert_response :unprocessable_entity
  end

  test "should destroy tag" do
    tag = document_tags(:acme_process_tag)
    assert_difference("DocumentTag.count", -1) do
      delete document_tag_url(tag)
    end
    assert_redirected_to document_tags_url
  end
end
