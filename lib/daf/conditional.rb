require 'daf/configurable'

module DAF
  # Base class for conditional nodes that allow altering flow of graph execution
  class Conditional
    include Configurable

    # Evaluates the condition and determines the next node to execute
    #
    # @param options [Hash] A hash of options with name/value pairs, must
    # match types expected for each option or will raise an exception
    # @param next_node [CommandGraphNode] The next node that would normally execute
    # @return [CommandGraphNode, nil] The next node to execute, or nil to halt execution
    def evaluate(options, next_node)
      process_options(options)
      determine_next_node(next_node)
    end
  end
end
