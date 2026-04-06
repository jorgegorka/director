require "test_helper"

class DocumentTagTest < ActiveSupport::TestCase
  setup do
    @project = projects(:acme)
    @widgets = projects(:widgets)
    @tag = document_tags(:acme_policy_tag)
  end

  test "valid with name and project" do
    tag = DocumentTag.new(project: @project, name: "new-tag")
    assert tag.valid?
  end

  test "invalid without name" do
    tag = DocumentTag.new(project: @project, name: nil)
    assert_not tag.valid?
    assert_includes tag.errors[:name], "can't be blank"
  end

  test "invalid with duplicate name in same project" do
    tag = DocumentTag.new(project: @project, name: "policy")
    assert_not tag.valid?
    assert tag.errors[:name].any?
  end

  test "allows duplicate name across different projects" do
    tag = DocumentTag.new(project: @widgets, name: "policy")
    assert tag.valid?
  end

  test "belongs to project via Tenantable" do
    assert_equal @project, @tag.project
  end

  test "has many documents through document_taggings" do
    assert @tag.respond_to?(:documents)
  end

  test "for_current_project scopes to Current.project" do
    Current.project = @project
    tags = DocumentTag.for_current_project
    assert_includes tags, document_tags(:acme_policy_tag)
    assert_not_includes tags, document_tags(:widgets_general_tag)
  end
end
