require "test_helper"

class DocumentTagTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @widgets = companies(:widgets)
    @tag = document_tags(:acme_policy_tag)
  end

  test "valid with name and company" do
    tag = DocumentTag.new(company: @company, name: "new-tag")
    assert tag.valid?
  end

  test "invalid without name" do
    tag = DocumentTag.new(company: @company, name: nil)
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "invalid with duplicate name in same company" do
    tag = DocumentTag.new(company: @company, name: "policy")
    assert_not tag.valid?
    assert tag.errors[:name].any?
  end

  test "allows duplicate name across different companies" do
    tag = DocumentTag.new(company: @widgets, name: "policy")
    assert tag.valid?
  end

  test "belongs to company via Tenantable" do
    assert_equal @company, @tag.company
  end

  test "has many documents through document_taggings" do
    assert @tag.respond_to?(:documents)
  end

  test "for_current_company scopes to Current.company" do
    Current.company = @company
    tags = DocumentTag.for_current_company
    assert_includes tags, document_tags(:acme_policy_tag)
    assert_not_includes tags, document_tags(:widgets_general_tag)
  end
end
