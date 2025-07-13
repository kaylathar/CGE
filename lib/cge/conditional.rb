# frozen_string_literal: true

require 'cge/command'

module CGE
  # Base class for conditional nodes that allow altering flow of graph execution
  class Conditional < Command
    # Execute this conditional - evaluates condition and determines next command
    #
    # @param inputs [Hash] A hash of inputs with name/value pairs, must
    # match types expected for each input or will raise an exception
    # @param next_command [Command] The next command that would normally execute
    # @param command_graph [CommandGraph] The command graph context for execution
    # @return [Command, nil] The next command to execute, or nil to halt execution
    def execute(inputs, next_command, command_graph)
      process_inputs(inputs)
      determine_next_node(next_command, command_graph)
    end
  end
end
