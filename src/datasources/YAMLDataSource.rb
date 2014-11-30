require 'yaml'
require_relative '../Command'
require_relative '../monitors/FileUpdateMonitor'
require_relative '../actions/EmailAction'

# A datasource that is parsed out of a YAML file
# does not permit any dynamic updates, but useful
# for a basic command parser
class YAMLDataSource < CommandDataSource
  attr_reader :monitor, :action,:actionOptions
 
  # Accepts the path of the YAML file to be parsed into
  # commands - will throw a CommandException should it have
  # invalid parameters
  def initialize(filePath)
    configuration = YAML.load_file(filePath)    
    #begin
      actionClass = get_class(configuration["Action"]["Type"])
      monitorClass = get_class(configuration["Monitor"]["Type"])
    #rescue
    #  raise CommandException, "Invalid Action or Monitor type" 
    #end

    @monitor = monitorClass.new(configuration["Monitor"]["Options"])
    @action = actionClass.new()
    @actionOptions = configuration["Action"]["Options"]
  end
  
  def get_class(className)
    Object.const_get(className)
  end

end
