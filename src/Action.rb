require_relative 'Configurable'
class Action
  extend Configurable

  def activate(options)
    process_options(options)
    success = invoke
    yield success if block_given?
    success
  end
end
