class HttpAdapter < BaseAdapter
  def self.display_name
    "HTTP API"
  end

  def self.description
    "Connect to a cloud-hosted agent via HTTP POST requests"
  end

  def self.execute(agent, context)
    # Phase 7: Implement via Faraday POST to agent.adapter_config["url"]
    raise NotImplementedError, "Heartbeat execution comes in Phase 7"
  end

  def self.test_connection(agent)
    # Phase 7: HEAD/GET request to verify endpoint is reachable
    raise NotImplementedError, "Connection testing comes in Phase 7"
  end
end
