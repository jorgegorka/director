require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @widgets = companies(:widgets)
    @user = users(:one)
    @document = documents(:acme_refund_policy)
  end

  test "valid with title, body, author, and company" do
    doc = Document.new(
      company: @company,
      title: "New Doc",
      body: "# Content",
      author: @user
    )
    assert doc.valid?
  end

  test "invalid without title" do
    doc = Document.new(company: @company, title: nil, body: "# Content", author: @user)
    assert_not doc.valid?
    assert_includes doc.errors[:title], "can't be blank"
  end

  test "invalid without body" do
    doc = Document.new(company: @company, title: "Test", body: nil, author: @user)
    assert_not doc.valid?
    assert_includes doc.errors[:body], "can't be blank"
  end

  test "invalid without author" do
    doc = Document.new(company: @company, title: "Test", body: "# Content")
    assert_not doc.valid?
    assert doc.errors[:author].any?
  end

  test "belongs to company via Tenantable" do
    assert_equal @company, @document.company
  end

  test "has polymorphic author" do
    assert_equal @user, @document.author
    agent_doc = documents(:acme_agent_created_doc)
    assert_equal agents(:claude_agent), agent_doc.author
  end

  test "has many skills through skill_documents" do
    assert @document.respond_to?(:skills)
  end

  test "has many agents through agent_documents" do
    assert @document.respond_to?(:agents)
  end

  test "has many tasks through task_documents" do
    assert @document.respond_to?(:tasks)
  end

  test "has many tags through document_taggings" do
    assert @document.respond_to?(:tags)
  end

  test "for_current_company scopes to Current.company" do
    Current.company = @company
    docs = Document.for_current_company
    assert_includes docs, documents(:acme_refund_policy)
    assert_not_includes docs, documents(:widgets_doc)
  end

  test "tagged_with filters by tag name" do
    # fixture refund_policy_tagged_policy already tags acme_refund_policy with policy
    results = Document.tagged_with("policy")
    assert_includes results, @document
    assert_not_includes results, documents(:acme_coding_standards)
  end

  test "by_author filters by author" do
    user_docs = Document.by_author(@user)
    assert_includes user_docs, @document
    assert_not_includes user_docs, documents(:acme_agent_created_doc)
  end

  test "destroying document destroys skill_documents" do
    doc = documents(:acme_coding_standards)
    SkillDocument.create!(skill: skills(:acme_code_review), document: doc)
    assert_difference("SkillDocument.count", -1) { doc.destroy }
  end

  test "destroying document destroys agent_documents" do
    doc = documents(:acme_coding_standards)
    AgentDocument.create!(agent: agents(:claude_agent), document: doc)
    assert_difference("AgentDocument.count", -1) { doc.destroy }
  end

  test "destroying document destroys task_documents" do
    doc = documents(:acme_coding_standards)
    TaskDocument.create!(task: tasks(:design_homepage), document: doc)
    assert_difference("TaskDocument.count", -1) { doc.destroy }
  end

  test "destroying document destroys document_taggings" do
    # fixture refund_policy_tagged_policy already tags @document
    assert @document.document_taggings.any?
    assert_difference("DocumentTagging.count", -1) { @document.destroy }
  end
end
