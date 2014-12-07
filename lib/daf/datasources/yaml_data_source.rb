require 'yaml'
require 'daf/command'

# A datasource that is parsed out of a YAML file
# does not permit any dynamic updates, but useful
# for a basic command parser
module DAF
  class YAMLDataSource < CommandDataSource
    attr_reader :monitor, :action, :action_options

    # Accepts the path of the YAML file to be parsed into
    # commands - will throw a CommandException should it have
    # invalid parameters
    #
    # @param filePath [String] Path for YAML file
    def initialize(file_path)
      configuration = YAML.load_file(file_path)
      action_class, monitor_class = action_monitor_classes(configuration)
      @monitor = monitor_class.new(configuration['Monitor']['Options'])
      @action = action_class.new
      @action_options = configuration['Action']['Options']
    end

    def action_monitor_classes(configuration)
      begin
        action_class = get_class(configuration['Action']['Type'])
        monitor_class = get_class(configuration['Monitor']['Type'])
      rescue
        raise CommandException, 'Invalid Action or Monitor type'
      end
      [action_class, monitor_class]
    end

    def get_class(class_name)
      Object.const_get(class_name)
    end
  end
end
