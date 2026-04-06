require "test_helper"

class SkillDocumentTest < ActiveSupport::TestCase
  setup do
    @skill = skills(:acme_code_review)
    @document = documents(:acme_refund_policy)
    @widgets_document = documents(:widgets_doc)
  end

  test "valid with skill and document from same project" do
    sd = SkillDocument.new(skill: @skill, document: @document)
    assert sd.valid?
  end

  test "invalid with duplicate skill and document pair" do
    sd = SkillDocument.new(
      skill: skills(:acme_code_review),
      document: documents(:acme_coding_standards)
    )
    assert_not sd.valid?
    assert sd.errors[:document_id].any?
  end

  test "allows same document on different skills" do
    sd = SkillDocument.new(
      skill: skills(:acme_strategic_planning),
      document: documents(:acme_coding_standards)
    )
    assert sd.valid?
  end

  test "invalid when skill and document from different projects" do
    sd = SkillDocument.new(skill: @skill, document: @widgets_document)
    assert_not sd.valid?
    assert_includes sd.errors[:document], "must belong to the same project as the skill"
  end

  test "belongs to skill" do
    sd = skill_documents(:code_review_has_coding_standards)
    assert_equal skills(:acme_code_review), sd.skill
  end

  test "belongs to document" do
    sd = skill_documents(:code_review_has_coding_standards)
    assert_equal documents(:acme_coding_standards), sd.document
  end
end
