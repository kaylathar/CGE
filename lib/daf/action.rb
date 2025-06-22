require 'daf/configurable'

module DAF
  # Stores information related to actions that can
  # be taken as a result of a Monitor firing
  # Exposes only one method, and is a Configurable
  class Action
    include Configurable

    # Activate this action using given options
    #
    # @param options [Hash] A hash of options with name/value pairs, must
    # match types expected for each option or will raise an exception
    # @return The output from the action
    def activate(options)
      process_options(options)
      invoke
    end
  end
end
