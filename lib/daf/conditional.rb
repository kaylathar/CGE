require 'daf/command'

module DAF
  # Base class for conditional nodes that allow altering flow of graph execution
  class Conditional < Command
    # Execute this conditional - evaluates condition and determines next command
    #
    # @param options [Hash] A hash of options with name/value pairs, must
    # match types expected for each option or will raise an exception
    # @param next_command [Command] The next command that would normally execute
    # @return [Command, nil] The next command to execute, or nil to halt execution
    def execute(options, next_command)
      process_options(options)
      determine_next_node(next_command)
    end
  end
end
