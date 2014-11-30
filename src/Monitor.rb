require_relative 'Configurable'

class Monitor
  extend Configurable

  def initialize(options)
    process_options(options)
  end

  def on_trigger
    Thread.new do
      loop do
        block_until_triggered
        yield
      end
    end
  end

end
