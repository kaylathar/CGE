require_relative 'Configurable'

class Monitor
  extend Configurable

  def initialize(options)
    process_options(options)
  end

end
