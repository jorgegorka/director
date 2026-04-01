module Tools
  class BaseTool
    attr_reader :role

    def initialize(role)
      @role = role
    end

    def name
      raise NotImplementedError
    end

    def definition
      raise NotImplementedError
    end

    def call(arguments)
      raise NotImplementedError
    end

    private

    def company
      role.company
    end
  end
end
