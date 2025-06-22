require 'securerandom'
require 'cge/configurable'

module CGE
  # Base class for all command types in the CGE framework
  # Provides common functionality for processing inputs and executing commands
  class Command
    include Configurable

    attr_reader :name, :inputs, :next_command, :id

    # @param id [String] Optional unique identifier for this command (auto-generated if not provided)
    # @param name [String] The name of this command
    # @param inputs [Hash] Initial inputs for this command
    # @param next_command [Command] The next command to execute after this one
    def initialize(id, name, inputs, next_command = nil)
      @id = id || SecureRandom.uuid
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
