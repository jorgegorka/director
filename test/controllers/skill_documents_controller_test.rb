require "test_helper"

class SkillDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:acme)
    sign_in_as(@user)
    post project_switch_url(@project)
    @skill = skills(:acme_code_review)
  end

  test "should link document to skill" do
    doc = documents(:acme_refund_policy)
    assert_difference("SkillDocument.count", 1) do
      post skill_skill_documents_url(@skill), params: { document_id: doc.id }
    end
    assert_redirected_to skill_url(@skill)
  end

  test "should not duplicate link" do
    doc = documents(:acme_coding_standards) # already linked via fixture
    assert_no_difference("SkillDocument.count") do
      post skill_skill_documents_url(@skill), params: { document_id: doc.id }
    end
    assert_redirected_to skill_url(@skill)
  end

  test "should unlink document from skill" do
    sd = skill_documents(:code_review_has_coding_standards)
    assert_difference("SkillDocument.count", -1) do
      delete skill_skill_document_url(@skill, sd)
    end
    assert_redirected_to skill_url(@skill)
  end
end
