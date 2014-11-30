Dir[File.dirname(__FILE__) + '/monitors/*'].each { |file| require file }
Dir[File.dirname(__FILE__) + '/actions/*'].each { |file| require file }
require 'yaml'

class Command
  def initialize(filePath)
    @configuration = YAML.load_file(filePath)    
    begin
      actionClass = get_class(@configuration["Action"]["Type"])
      monitorClass = get_class(@configuration["Monitor"]["Type"])
    rescue
      raise CommandException, "Invalid Action or Monitor" 
    end

    @monitor = monitorClass.new(@configuration["Monitor"]["Options"])
    @action = actionClass.new()
    @options = @configuration["Action"]["Options"]
  end
  
  def get_class(className)
    Object.const_get(className)
  end

  def execute
    @monitor.on_trigger do
      @action.activate(@options)
    end  
  end 
end

class CommandException < Exception
end
