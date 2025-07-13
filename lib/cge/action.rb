# frozen_string_literal: true

require 'cge/command'

module CGE
  # Stores information related to actions that can
  # be taken as a result of a Monitor firing
  class Action < Command
    # Execute this action using given inputs
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
