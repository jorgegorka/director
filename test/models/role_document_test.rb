require "test_helper"

class RoleDocumentTest < ActiveSupport::TestCase
  setup do
    @role = roles(:cto)
    @document = documents(:acme_coding_standards)
    @widgets_document = documents(:widgets_doc)
  end

  test "valid with role and document from same company" do
    rd = RoleDocument.new(role: @role, document: @document)
    assert rd.valid?
  end

  test "invalid with duplicate role and document pair" do
    rd = RoleDocument.new(
      role: roles(:cto),
      document: documents(:acme_refund_policy)
    )
    assert_not rd.valid?
    assert rd.errors[:document_id].any?
  end

  test "allows same document on different roles" do
    rd = RoleDocument.new(
      role: roles(:developer),
      document: documents(:acme_refund_policy)
    )
    assert rd.valid?
  end

  test "invalid when role and document from different companies" do
    rd = RoleDocument.new(role: @role, document: @widgets_document)
    assert_not rd.valid?
    assert_includes rd.errors[:document], "must belong to the same company as the role"
  end

  test "belongs to role" do
    rd = role_documents(:cto_has_refund_policy)
    assert_equal roles(:cto), rd.role
  end

  test "belongs to document" do
    rd = role_documents(:cto_has_refund_policy)
    assert_equal documents(:acme_refund_policy), rd.document
  end
end
