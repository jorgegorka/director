require "test_helper"

class RoleDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @role = roles(:cto)
  end

  test "should link document to role" do
    doc = documents(:acme_coding_standards)
    assert_difference("RoleDocument.count", 1) do
      post role_role_documents_url(@role), params: { document_id: doc.id }
    end
    assert_redirected_to role_url(@role)
  end

  test "should not duplicate link" do
    doc = documents(:acme_refund_policy) # already linked via fixture
    assert_no_difference("RoleDocument.count") do
      post role_role_documents_url(@role), params: { document_id: doc.id }
    end
    assert_redirected_to role_url(@role)
  end

  test "should unlink document from role" do
    rd = role_documents(:cto_has_refund_policy)
    assert_difference("RoleDocument.count", -1) do
      delete role_role_document_url(@role, rd)
    end
    assert_redirected_to role_url(@role)
  end
end
