require 'cge/command'

module CGE
  # Stores information related to actions that can
  # be taken as a result of a Monitor firing
  class Action < Command
    # Execute this action using given options
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
