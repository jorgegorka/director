module Adapters
  class ProcessAdapter < BaseAdapter
    def self.display_name
      "Shell Command"
    end

    def self.description
      "Run a local script or CLI tool via shell command"
    end

    def self.execute(agent, context)
      # Phase 7: Implement via Open3.capture3 with agent.adapter_config["command"]
      raise NotImplementedError, "Heartbeat execution comes in Phase 7"
    end

    def self.test_connection(agent)
      # Phase 7: Check command exists via `which` or dry-run
      raise NotImplementedError, "Connection testing comes in Phase 7"
    end
  end
end
