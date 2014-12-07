require_relative 'configurable'

# Stores information related to actions that can
# be taken as a result of a Monitor firing
# Exposes only one method, and is a Configurable
class Action
  include Configurable

  # Activate this action using given options - takes an optional
  # block parameter that will be invoked when action
  # is complete, with a parameter of if the action was successful
  # and also returns if action was successful
  #
  # @param options [Hash] A hash of options with name/value pairs, must
  # match types expected for each option or will raise an exception
  # @yield If successful, will execute the optional block passed in
  def activate(options)
    process_options(options)
    success = invoke
    yield success if block_given?
    success
  end
end
