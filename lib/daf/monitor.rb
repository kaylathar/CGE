require 'daf/configurable'

# Stores information relating to things being monitored
# sub-classes define specific criteria for when a monitor
# should 'go off'.  Has only one method, #on_trigger, that
# allows you to begin monitoring for an event
class Monitor
  include Configurable

  # Requires the set of options expected by this monitor
  #
  # @param options [Hash] The options in key/value format,
  # the type of each option must match that expected or an
  # exception will be raised
  def initialize(options)
    process_options(options)
  end

  # Begins monitoring for event, when event occurs will
  # execute required block parameter
  def on_trigger
    block_until_triggered
    yield
  end
end
