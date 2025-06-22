require 'cge/configurable'

module CGE
  # Base class for all command types in the CGE framework
  # Provides common functionality for processing options and executing commands
  class Command
    include Configurable

    attr_reader :name, :options, :next_command

    def initialize(name, options, next_command = nil)
      @name = name
      @options = options
      @next_command = next_command
    end

    # Executes the command with given options and next command
    #
    # @param options [Hash] A hash of options with name/value pairs, must
    # match types expected for each option or will raise an exception
    # @param next_command [Command] The next command to execute after this one
    # @return [Command] The next command to execute, typically next_command unless overridden
    def execute(options, next_command)
      process_options(options)
      next_command
    end
  end
end
