require_relative 'configurable'

# Stores information related to actions that can
# be taken as a result of a Monitor firing
# Exposes only one method, and is a Configurable
class Action
  extend Configurable

  # Activate this action using given options - takes an optional
  # block parameter that will be invoked when action
  # is complete, with a parameter of if the action was successful
  # and also returns if action was successful
  def activate(options)
    process_options(options)
    success = invoke
    yield success if block_given?
    success
  end
end
