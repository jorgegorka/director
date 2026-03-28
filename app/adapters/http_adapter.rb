class HttpAdapter < BaseAdapter
  # Error raised for 4xx responses -- permanent, no retry.
  class PermanentError < StandardError; end

  # Error raised for 5xx responses and network timeouts/connection failures
  # after all retries are exhausted -- transient but ultimately unrecoverable.
  class TransientError < StandardError; end

  OPEN_TIMEOUT = 5    # seconds, connect timeout
  READ_TIMEOUT = 30   # seconds, read timeout
  MAX_RETRIES  = 3    # total attempts for transient failures
  BASE_BACKOFF = 1    # seconds, base for exponential backoff (1s, 2s, 4s)

  def self.display_name
    "HTTP API"
  end

  def self.description
    "Connect to a cloud-hosted agent via HTTP POST requests"
  end

  def self.config_schema
    { required: %w[url], optional: %w[method headers auth_token timeout] }
  end

  # Sends a POST request to the agent's configured URL with task context as a
  # JSON payload. Returns a result hash on success. Raises PermanentError for
  # 4xx responses and TransientError for 5xx/timeout after MAX_RETRIES attempts.
  def self.execute(agent, context)
    url = agent.adapter_config["url"]
    raise PermanentError, "No URL configured" if url.blank?

    payload = build_payload(agent, context)
    response = deliver_with_retries(url, payload, agent.adapter_config)

    {
      exit_code: 0,
      response_code: response.code.to_i,
      response_body: response.body&.truncate(1000)
    }
  end

  # Overridable hook for backoff sleep -- enables zero-sleep in tests.
  def self.backoff_sleep(seconds)
    sleep(seconds)
  end

  private_class_method def self.build_payload(agent, context)
    {
      agent_id: agent.id,
      agent_name: agent.name,
      run_id: context[:run_id],
      trigger_type: context[:trigger_type],
      task: context[:task_id] ? {
        id: context[:task_id],
        title: context[:task_title],
        description: context[:task_description]
      } : nil,
      skills: context[:skills].presence,
      resume_session_id: context[:resume_session_id],
      delivered_at: Time.current.iso8601
    }.compact
  end

  private_class_method def self.deliver_with_retries(url, payload, config)
    uri  = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = (uri.scheme == "https")
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    # Allow per-agent timeout override (capped at 120s).
    if config["timeout"].present?
      http.read_timeout = [ config["timeout"].to_i, 120 ].min
    end

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    config["headers"]&.each { |k, v| request[k] = v }
    request["Authorization"] = "Bearer #{config["auth_token"]}" if config["auth_token"].present?
    request.body = payload.to_json

    last_error = nil
    MAX_RETRIES.times do |attempt|
      begin
        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          return response
        elsif response.is_a?(Net::HTTPClientError)
          raise PermanentError, "HTTP #{response.code}: #{response.body&.truncate(200)}"
        else
          # 5xx or unexpected non-success -- treat as transient
          last_error = TransientError.new("HTTP #{response.code}: #{response.body&.truncate(200)}")
        end
      rescue PermanentError
        raise
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
        last_error = TransientError.new(e.message)
      end

      backoff_sleep(BASE_BACKOFF * (2 ** attempt)) if attempt + 1 < MAX_RETRIES
    end

    raise last_error || TransientError.new("Delivery failed after #{MAX_RETRIES} attempts")
  end
end
