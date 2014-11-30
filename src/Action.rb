require_relative 'Configurable'
class Action
  extend Configurable

  def activate(options)
    process_options(options)
    yield invoke 
  end
end
