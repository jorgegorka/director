require "test_helper"

class CreateDocumentServiceTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @agent = agents(:claude_agent)
    @user = users(:one)
  end

  test "creates document with agent author" do
    doc = CreateDocumentService.call(
      author: @agent,
      company: @company,
      title: "Agent Report",
      body: "# Report\n\nFindings here."
    )

    assert doc.persisted?
    assert_equal "Agent Report", doc.title
    assert_equal @agent, doc.author
    assert_equal @company, doc.company
  end

  test "creates document with user author" do
    doc = CreateDocumentService.call(
      author: @user,
      company: @company,
      title: "User Doc",
      body: "# User Doc\n\nContent."
    )

    assert doc.persisted?
    assert_equal @user, doc.author
  end

  test "creates and links tags by name" do
    doc = CreateDocumentService.call(
      author: @agent,
      company: @company,
      title: "Tagged Doc",
      body: "# Content",
      tag_names: ["policy", "new-tag"]
    )

    assert doc.persisted?
    assert_equal 2, doc.tags.count
    assert_includes doc.tags.pluck(:name), "policy"
    assert_includes doc.tags.pluck(:name), "new-tag"
  end

  test "finds existing tags instead of creating duplicates" do
    existing_tag = document_tags(:acme_policy_tag)

    assert_no_difference("DocumentTag.where(name: 'policy', company: @company).count") do
      CreateDocumentService.call(
        author: @agent,
        company: @company,
        title: "Doc with existing tag",
        body: "# Content",
        tag_names: ["policy"]
      )
    end
  end

  test "raises on invalid document" do
    assert_raises(ActiveRecord::RecordInvalid) do
      CreateDocumentService.call(
        author: @agent,
        company: @company,
        title: "",
        body: "# Content"
      )
    end
  end

  test "does not auto-link document to author agent" do
    doc = CreateDocumentService.call(
      author: @agent,
      company: @company,
      title: "Standalone Doc",
      body: "# Content"
    )

    assert_equal 0, doc.agent_documents.count
  end
end
