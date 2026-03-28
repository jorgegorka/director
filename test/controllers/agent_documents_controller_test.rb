require "test_helper"

class AgentDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @agent = agents(:claude_agent)
  end

  test "should link document to agent" do
    doc = documents(:acme_coding_standards)
    assert_difference("AgentDocument.count", 1) do
      post agent_agent_documents_url(@agent), params: { document_id: doc.id }
    end
    assert_redirected_to agent_url(@agent)
  end

  test "should not duplicate link" do
    doc = documents(:acme_refund_policy) # already linked via fixture
    assert_no_difference("AgentDocument.count") do
      post agent_agent_documents_url(@agent), params: { document_id: doc.id }
    end
    assert_redirected_to agent_url(@agent)
  end

  test "should unlink document from agent" do
    ad = agent_documents(:claude_has_refund_policy)
    assert_difference("AgentDocument.count", -1) do
      delete agent_agent_document_url(@agent, ad)
    end
    assert_redirected_to agent_url(@agent)
  end
end
