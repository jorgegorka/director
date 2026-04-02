require "test_helper"

class Tools::GetDocumentTest < ActiveSupport::TestCase
  setup do
    @tool = Tools::GetDocument.new(roles(:cto))
  end

  test "returns full document content with tags" do
    doc = documents(:acme_refund_policy)
    result = @tool.call({ "document_id" => doc.id })

    assert_equal doc.id, result[:id]
    assert_equal "Refund Policy", result[:title]
    assert_includes result[:body], "Refund Policy"
    assert_includes result[:tags], "policy"
    assert result[:created_at].present?
    assert result[:updated_at].present?
  end

  test "raises not found for document from another company" do
    widgets_doc = documents(:widgets_doc)

    assert_raises(ActiveRecord::RecordNotFound) do
      @tool.call({ "document_id" => widgets_doc.id })
    end
  end

  test "raises not found for nonexistent document" do
    assert_raises(ActiveRecord::RecordNotFound) do
      @tool.call({ "document_id" => 999999 })
    end
  end
end
