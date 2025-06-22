require 'cge/configurable'

module CGE
  # Base class for all command types in the CGE framework
  # Provides common functionality for processing inputs and executing commands
  class Command
    include Configurable

    attr_reader :name, :inputs, :next_command

    def initialize(name, inputs, next_command = nil)
      @name = name
      @inputs = inputs
      @next_command = next_command
    end

    # Executes the command with given inputs and next command
    #
    # @param inputs [Hash] A hash of inputs with name/value pairs, must
    # match types expected for each input or will raise an exception
    # @param next_command [Command] The next command to execute after this one
    # @return [Command] The next command to execute, typically next_command unless overridden
    def execute(inputs, next_command)
      process_inputs(inputs)
      next_command
    end
  end
end
