class ProcessAdapter < BaseAdapter
  def self.display_name
    "Shell Command"
  end

  def self.description
    "Run a local script or CLI tool via shell command"
  end

  def self.config_schema
    { required: %w[command], optional: %w[working_directory env timeout] }
  end
end
