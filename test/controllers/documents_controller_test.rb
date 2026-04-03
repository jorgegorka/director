require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = companies(:acme)
    sign_in_as(@user)
    post company_switch_url(@company)
    @document = documents(:acme_refund_policy)
    @widgets_doc = documents(:widgets_doc)
  end

  # --- Index ---

  test "should get index" do
    get documents_url
    assert_response :success
  end

  test "should only show documents for current company" do
    get documents_url
    assert_response :success
  end

  # --- Show ---

  test "should show document" do
    get document_url(@document)
    assert_response :success
  end

  test "should not show document from another company" do
    get document_url(@widgets_doc)
    assert_redirected_to root_url
  end

  # --- New / Create ---

  test "should get new document form" do
    get new_document_url
    assert_response :success
    assert_select "form"
  end

  test "should create document" do
    assert_difference("Document.count", 1) do
      post documents_url, params: {
        document: {
          title: "New Document",
          body: "# New Document\n\nSome content."
        }
      }
    end
    doc = Document.order(:created_at).last
    assert_equal "New Document", doc.title
    assert_equal @user, doc.author
    assert_equal @company, doc.company
    assert_redirected_to document_url(doc)
  end

  test "should create document with tags" do
    tag = document_tags(:acme_policy_tag)
    post documents_url, params: {
      document: {
        title: "Tagged Doc",
        body: "# Content",
        tag_ids: [ tag.id ]
      }
    }
    doc = Document.order(:created_at).last
    assert_includes doc.tags, tag
  end

  test "should not create document without title" do
    assert_no_difference("Document.count") do
      post documents_url, params: {
        document: { title: "", body: "# Content" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create document without body" do
    assert_no_difference("Document.count") do
      post documents_url, params: {
        document: { title: "Test", body: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test "should get edit form" do
    get edit_document_url(@document)
    assert_response :success
    assert_select "form"
  end

  test "should update document" do
    patch document_url(@document), params: {
      document: { title: "Updated Title", body: "# Updated\n\nNew body." }
    }
    assert_redirected_to document_url(@document)
    @document.reload
    assert_equal "Updated Title", @document.title
    assert_equal @user, @document.last_editor
  end

  test "should not update document with blank title" do
    patch document_url(@document), params: {
      document: { title: "" }
    }
    assert_response :unprocessable_entity
  end

  test "should not update document from another company" do
    patch document_url(@widgets_doc), params: {
      document: { title: "Hacked" }
    }
    assert_redirected_to root_url
  end

  # --- Destroy ---

  test "should destroy document" do
    assert_difference("Document.count", -1) do
      delete document_url(@document)
    end
    assert_redirected_to documents_url
  end

  test "should not destroy document from another company" do
    assert_no_difference("Document.count") do
      delete document_url(@widgets_doc)
    end
    assert_redirected_to root_url
  end

  # --- Auth ---

  test "should redirect unauthenticated user" do
    sign_out
    get documents_url
    assert_redirected_to new_session_url
  end
end
