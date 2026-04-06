require "test_helper"

class TaskDocumentTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:design_homepage)
    @document = documents(:acme_refund_policy)
    @widgets_document = documents(:widgets_doc)
  end

  test "valid with task and document from same project" do
    td = TaskDocument.new(task: @task, document: @document)
    assert td.valid?
  end

  test "invalid with duplicate task and document pair" do
    td = TaskDocument.new(
      task: tasks(:design_homepage),
      document: documents(:acme_coding_standards)
    )
    assert_not td.valid?
    assert td.errors[:document_id].any?
  end

  test "allows same document on different tasks" do
    td = TaskDocument.new(
      task: tasks(:fix_login_bug),
      document: documents(:acme_coding_standards)
    )
    assert td.valid?
  end

  test "invalid when task and document from different projects" do
    td = TaskDocument.new(task: @task, document: @widgets_document)
    assert_not td.valid?
    assert_includes td.errors[:document], "must belong to the same project as the task"
  end

  test "belongs to task" do
    td = task_documents(:homepage_has_coding_standards)
    assert_equal tasks(:design_homepage), td.task
  end

  test "belongs to document" do
    td = task_documents(:homepage_has_coding_standards)
    assert_equal documents(:acme_coding_standards), td.document
  end
end
