# frozen_string_literal: true

require 'cge/command'

module CGE
  # Stores information relating to things being monitored
  # sub-classes define specific criteria for when a monitor
  # should 'go off'
  class Monitor < Command
    # Execute this monitor - begins monitoring for event
    #
    # @param inputs [Hash] The inputs in key/value format,
    # the type of each input must match that expected or an
    # exception will be raised
    # @param next_command [Command] The next command that would normally execute
    # @param command_graph [CommandGraph] The command graph context for execution
    # @return [Command] The next command to execute
    def execute(inputs, next_command, _command_graph)
      process_inputs(inputs)
      block_until_triggered
      next_command
    end
  end
end
