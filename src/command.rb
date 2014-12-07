Dir[File.dirname(__FILE__) + '/monitors/*'].each { |file| require file }
Dir[File.dirname(__FILE__) + '/actions/*'].each { |file| require file }

# Represents a pair of Action and Monitor objects
# when requested, will begin watching the Monitor
# and when it triggers will invoke the action by
# default Command continues monitoring forever
# though subclasses may override this behavior
class Command
  # Create a new command object form a data source
  # @param datasource [CommandDataSource] The data source to use to initialize
  # command object
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

# Exception generated during loading or execution of command
class CommandException < Exception
end

# Data source to initialize command with
class CommandDataSource
  # Overridden by subclasses - returns options that should be passed to action
  def action_options
  end

  # Overridden by subclasses - returns action that should be used by command
  def action
  end

  def monitor
  end
end
