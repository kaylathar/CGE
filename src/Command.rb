Dir[File.dirname(__FILE__) + '/monitors/*'].each { |file| require file } 
Dir[File.dirname(__FILE__) + '/actions/*'].each { |file| require file }

# Represents a pair of Action and Monitor objects
# when requested, will begin watching the Monitor
# and when it triggers will invoke the action by
# default Command continues monitoring forever
# though subclasses may override this behavior
class Command
  def initialize(datasource)
    @datasource = datasource
  end

  # Begins executing the command by starting the monitor
  def execute
    Thread.new do
      loop do
        @datasource.monitor.on_trigger do
          @datasource.action.activate(@datasource.actionOptions)
        end
      end
    end
  end
end

class CommandException < Exception
end

class CommandDataSource

  # Overridden by subclasses - returns options that should be passed to action
  def actionOptions
  end

  # Overridden by subclasses - returns action that should be used by command
  def action
  end
  
  # Overridden by subclasses - returns monitor that should be used by command 
  def monitor
  end
end
