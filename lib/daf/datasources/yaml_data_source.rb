require 'yaml'
require 'daf/command'

module DAF
  # A datasource that is parsed out of a YAML file
  # does not permit any dynamic updates, but useful
  # for a basic command parser
  class YAMLDataSource < CommandDataSource
    attr_reader :monitor, :action

    # Accepts the path of the YAML file to be parsed into
    # commands - will throw a CommandException should it have
    # invalid parameters
    #
    # @param filePath [String] Path for YAML file
    def initialize(file_path)
      configuration = YAML.load_file(file_path)
      @action_class, @monitor_class = action_monitor_classes(configuration)
      @monitor = @monitor_class.new(configuration['Monitor']['Options'])
      @action = @action_class.new
      @action_options = configuration['Action']['Options']
    end

    def action_options
      # Attempt resolution to outputs of monitor
      return @action_options unless @monitor_class.outputs.length > 0
      action_options = @action_options.clone
      @monitor_class.outputs.each do |output, _type|
        action_options.each do |option_key, option_value|
          action_options[option_key] =
            option_value.gsub("{{#{output}}}", @monitor.send(output).to_s)
        end
      end
      action_options
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

    protected :get_class, :action_monitor_classes
  end
end
