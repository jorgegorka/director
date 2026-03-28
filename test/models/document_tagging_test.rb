require "test_helper"

class DocumentTaggingTest < ActiveSupport::TestCase
  setup do
    @document = documents(:acme_refund_policy)
    @tag = document_tags(:acme_technical_tag)
  end

  test "valid with document and tag" do
    tagging = DocumentTagging.new(document: @document, document_tag: @tag)
    assert tagging.valid?
  end

  test "invalid with duplicate document and tag pair" do
    tagging = DocumentTagging.new(
      document: documents(:acme_refund_policy),
      document_tag: document_tags(:acme_policy_tag)
    )
    assert_not tagging.valid?
    assert tagging.errors[:document_tag_id].any?
  end

  test "allows same tag on different documents" do
    tagging = DocumentTagging.new(
      document: documents(:acme_coding_standards),
      document_tag: document_tags(:acme_policy_tag)
    )
    assert tagging.valid?
  end

  test "belongs to document" do
    tagging = document_taggings(:refund_policy_tagged_policy)
    assert_equal @document, tagging.document
  end

  test "belongs to document_tag" do
    tagging = document_taggings(:refund_policy_tagged_policy)
    assert_equal document_tags(:acme_policy_tag), tagging.document_tag
  end
end
