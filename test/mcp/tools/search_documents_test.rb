require "test_helper"

class Tools::SearchDocumentsTest < ActiveSupport::TestCase
  setup do
    @tool = Tools::SearchDocuments.new(roles(:cto))
  end

  test "returns all project documents with no filters" do
    result = @tool.call({})

    titles = result[:documents].map { |d| d[:title] }
    assert_includes titles, "Refund Policy"
    assert_includes titles, "Coding Standards"
    assert_includes titles, "Process Documentation"
    assert result[:count] >= 3
  end

  test "filters by title query" do
    result = @tool.call({ "query" => "Refund" })

    titles = result[:documents].map { |d| d[:title] }
    assert_includes titles, "Refund Policy"
    assert_not_includes titles, "Coding Standards"
  end

  test "filters by tag" do
    result = @tool.call({ "tag" => "policy" })

    titles = result[:documents].map { |d| d[:title] }
    assert_includes titles, "Refund Policy"
    assert_not_includes titles, "Coding Standards"
  end

  test "returns empty results for non-matching query" do
    result = @tool.call({ "query" => "nonexistent_xyz" })

    assert_equal 0, result[:count]
    assert_empty result[:documents]
  end

  test "does not return documents from another project" do
    result = @tool.call({})

    titles = result[:documents].map { |d| d[:title] }
    assert_not_includes titles, "Widget Specs"
  end

  test "results include tags but not body" do
    result = @tool.call({ "tag" => "policy" })

    doc = result[:documents].find { |d| d[:title] == "Refund Policy" }
    assert_includes doc[:tags], "policy"
    assert_nil doc[:body]
  end
end
