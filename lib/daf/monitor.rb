require 'daf/configurable'

module DAF
  # Stores information relating to things being monitored
  # sub-classes define specific criteria for when a monitor
  # should 'go off'.  Has only one method, #on_trigger, that
  # allows you to begin monitoring for an event
  class Monitor
    include Configurable

    # Begins monitoring for event, when event occurs will return
    #
    # @param options [Hash] The options in key/value format,
    # the type of each option must match that expected or an
    # exception will be raised
    def on_trigger(options)
      process_options(options)
      block_until_triggered
    end
  end
end
