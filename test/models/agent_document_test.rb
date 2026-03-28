require "test_helper"

class AgentDocumentTest < ActiveSupport::TestCase
  setup do
    @agent = agents(:claude_agent)
    @document = documents(:acme_coding_standards)
    @widgets_document = documents(:widgets_doc)
  end

  test "valid with agent and document from same company" do
    ad = AgentDocument.new(agent: @agent, document: @document)
    assert ad.valid?
  end

  test "invalid with duplicate agent and document pair" do
    ad = AgentDocument.new(
      agent: agents(:claude_agent),
      document: documents(:acme_refund_policy)
    )
    assert_not ad.valid?
    assert ad.errors[:document_id].any?
  end

  test "allows same document on different agents" do
    ad = AgentDocument.new(
      agent: agents(:http_agent),
      document: documents(:acme_refund_policy)
    )
    assert ad.valid?
  end

  test "invalid when agent and document from different companies" do
    ad = AgentDocument.new(agent: @agent, document: @widgets_document)
    assert_not ad.valid?
    assert_includes ad.errors[:document], "must belong to the same company as the agent"
  end

  test "belongs to agent" do
    ad = agent_documents(:claude_has_refund_policy)
    assert_equal agents(:claude_agent), ad.agent
  end

  test "belongs to document" do
    ad = agent_documents(:claude_has_refund_policy)
    assert_equal documents(:acme_refund_policy), ad.document
  end
end
