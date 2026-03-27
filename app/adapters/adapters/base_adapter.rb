module Adapters
  class BaseAdapter
    def self.execute(agent, context)
      raise NotImplementedError, "#{name} must implement .execute"
    end

    def self.test_connection(agent)
      raise NotImplementedError, "#{name} must implement .test_connection"
    end

    def self.display_name
      raise NotImplementedError, "#{name} must implement .display_name"
    end

    def self.description
      raise NotImplementedError, "#{name} must implement .description"
    end
  end
end
