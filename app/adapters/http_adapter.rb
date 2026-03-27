class HttpAdapter < BaseAdapter
  def self.display_name
    "HTTP API"
  end

  def self.description
    "Connect to a cloud-hosted agent via HTTP POST requests"
  end

  def self.config_schema
    { required: %w[url], optional: %w[method headers auth_token timeout] }
  end
end
