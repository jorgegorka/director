require "test_helper"

class Documents::CreatorTest < ActiveSupport::TestCase
  setup do
    @company = companies(:acme)
    @role = roles(:cto)
    @user = users(:one)
  end

  test "creates document with role author" do
    doc = Documents::Creator.call(
      author: @role,
      company: @company,
      title: "Role Report",
      body: "# Report\n\nFindings here."
    )

    assert doc.persisted?
    assert_equal "Role Report", doc.title
    assert_equal @role, doc.author
    assert_equal @company, doc.company
  end

  test "creates document with user author" do
    doc = Documents::Creator.call(
      author: @user,
      company: @company,
      title: "User Doc",
      body: "# User Doc\n\nContent."
    )

    assert doc.persisted?
    assert_equal @user, doc.author
  end

  test "creates and links tags by name" do
    doc = Documents::Creator.call(
      author: @role,
      company: @company,
      title: "Tagged Doc",
      body: "# Content",
      tag_names: [ "policy", "new-tag" ]
    )

    assert doc.persisted?
    assert_equal 2, doc.tags.count
    assert_includes doc.tags.pluck(:name), "policy"
    assert_includes doc.tags.pluck(:name), "new-tag"
  end

  test "finds existing tags instead of creating duplicates" do
    existing_tag = document_tags(:acme_policy_tag)

    assert_no_difference("DocumentTag.where(name: 'policy', company: @company).count") do
      Documents::Creator.call(
        author: @role,
        company: @company,
        title: "Doc with existing tag",
        body: "# Content",
        tag_names: [ "policy" ]
      )
    end
  end

  test "raises on invalid document" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Documents::Creator.call(
        author: @role,
        company: @company,
        title: "",
        body: "# Content"
      )
    end
  end
end
