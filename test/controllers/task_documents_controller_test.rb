require "test_helper"

class TaskDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @task = tasks(:design_homepage)
  end

  test "should link document to task" do
    doc = documents(:acme_refund_policy)
    assert_difference("TaskDocument.count", 1) do
      post task_task_documents_url(@task), params: { document_id: doc.id }
    end
    assert_redirected_to task_url(@task)
  end

  test "should not duplicate link" do
    doc = documents(:acme_coding_standards) # already linked via fixture
    assert_no_difference("TaskDocument.count") do
      post task_task_documents_url(@task), params: { document_id: doc.id }
    end
    assert_redirected_to task_url(@task)
  end

  test "should unlink document from task" do
    td = task_documents(:homepage_has_coding_standards)
    assert_difference("TaskDocument.count", -1) do
      delete task_task_document_url(@task, td)
    end
    assert_redirected_to task_url(@task)
  end
end
