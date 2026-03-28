require "test_helper"

class AiClientTest < ActiveSupport::TestCase
  setup do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
  end

  test "chat returns parsed JSON response" do
    mock_response = {
      "content" => [ { "type" => "text", "text" => '{"result":"pass","feedback":"Good work"}' } ],
      "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })

    result = AiClient.chat(
      system: "You are an evaluator.",
      prompt: "Evaluate this task."
    )

    assert_equal "pass", result[:parsed]["result"]
    assert_equal "Good work", result[:parsed]["feedback"]
    assert_equal 100, result[:usage]["input_tokens"]
    assert_equal 50, result[:usage]["output_tokens"]
  end

  test "chat raises on API error" do
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 500, body: '{"error":{"message":"Internal error"}}')

    assert_raises(AiClient::ApiError) do
      AiClient.chat(system: "test", prompt: "test")
    end
  end

  test "chat raises on invalid JSON in response text" do
    mock_response = {
      "content" => [ { "type" => "text", "text" => "not valid json" } ],
      "usage" => { "input_tokens" => 10, "output_tokens" => 5 }
    }.to_json

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: mock_response, headers: { "Content-Type" => "application/json" })

    assert_raises(AiClient::ParseError) do
      AiClient.chat(system: "test", prompt: "test")
    end
  end

  test "estimate_cost_cents calculates from usage" do
    usage = { "input_tokens" => 1000, "output_tokens" => 500 }
    cost = AiClient.estimate_cost_cents(usage)
    assert_kind_of Integer, cost
    assert cost >= 0
  end
end
