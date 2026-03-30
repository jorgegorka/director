module Agents
  class AiClient
    API_URL = "https://api.anthropic.com/v1/messages".freeze
    MODEL = "claude-sonnet-4-20250514".freeze
    MAX_TOKENS = 1024

    INPUT_COST_PER_MILLION = 3.0
    OUTPUT_COST_PER_MILLION = 15.0

    class ApiError < StandardError; end
    class ParseError < StandardError; end

    def self.chat(system:, prompt:, model: MODEL, max_tokens: MAX_TOKENS)
      new.chat(system: system, prompt: prompt, model: model, max_tokens: max_tokens)
    end

    def self.estimate_cost_cents(usage)
      input_cost = (usage["input_tokens"].to_f / 1_000_000) * INPUT_COST_PER_MILLION
      output_cost = (usage["output_tokens"].to_f / 1_000_000) * OUTPUT_COST_PER_MILLION
      ((input_cost + output_cost) * 100).ceil
    end

    def chat(system:, prompt:, model: MODEL, max_tokens: MAX_TOKENS)
      body = {
        model: model,
        max_tokens: max_tokens,
        system: system,
        messages: [ { role: "user", content: prompt } ]
      }

      response = post_request(body)

      unless response.is_a?(Net::HTTPSuccess)
        error_msg = (JSON.parse(response.body).dig("error", "message") rescue nil) || "API request failed with status #{response.code}"
        raise ApiError, error_msg
      end

      parsed_body = JSON.parse(response.body)
      text = parsed_body.dig("content", 0, "text")
      parsed_text = parse_json_response(text)

      {
        parsed: parsed_text,
        usage: parsed_body["usage"],
        raw_text: text
      }
    end

    private

    def post_request(body)
      uri = URI(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["x-api-key"] = api_key
      request["anthropic-version"] = "2023-06-01"
      request.body = body.to_json

      http.request(request)
    end

    def api_key
      Rails.application.credentials.dig(:anthropic, :api_key) ||
        ENV["ANTHROPIC_API_KEY"] ||
        raise(ApiError, "No Anthropic API key configured. Set credentials.anthropic.api_key or ANTHROPIC_API_KEY env var.")
    end

    def parse_json_response(text)
      JSON.parse(text)
    rescue JSON::ParserError => e
      raise ParseError, "Failed to parse AI response as JSON: #{e.message}"
    end
  end
end
