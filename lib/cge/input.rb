# frozen_string_literal: true

require 'cge/command'

module CGE
  # Stores information from an input source into the command graph
  class Input < Command
    # Execute this input - processes input and inserts it into the graph data
    #
    # @param inputs [Hash] A hash of inputs with name/value pairs, must
    # match types expected for each input or will raise an exception
    # @param next_command [Command] The next command that would normally execute
    # @param command_graph [CommandGraph] The command graph context for execution
    # @return [Command] The next command to execute
    def execute(inputs, next_command, _command_graph)
      process_inputs(inputs)
      invoke
      next_command
    end
  end
end
