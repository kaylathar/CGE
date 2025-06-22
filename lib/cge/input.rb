require 'cge/command'

module CGE
  # Stores information from an input source into the command graph
  class Input < Command
    # Execute this input - processes input and inserts it into the graph data
    #
    # @param options [Hash] A hash of options with name/value pairs, must
    # match types expected for each option or will raise an exception
    # @param next_command [Command] The next command to execute after this one
    # @return [Command] The next command to execute
    def execute(options, next_command)
      process_options(options)
      invoke
      next_command
    end
  end
end
