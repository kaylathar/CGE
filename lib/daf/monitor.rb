require 'daf/command'

module DAF
  # Stores information relating to things being monitored
  # sub-classes define specific criteria for when a monitor
  # should 'go off'
  class Monitor < Command
    # Execute this monitor - begins monitoring for event
    #
    # @param options [Hash] The options in key/value format,
    # the type of each option must match that expected or an
    # exception will be raised
    # @param next_command [Command] The next command to execute after this one
    # @return [Command] The next command to execute
    def execute(options, next_command)
      process_options(options)
      block_until_triggered
      next_command
    end
  end
end
