require 'yaml'
require 'cge/command_graph'

module CGE
  # A command graph that is parsed out of a YAML file
  #
  # Loads and constructs a command graph from YAML configuration files.
  # The YAML file should contain a Name and Graph structure defining
  # the sequence of monitors and actions to execute.
  #
  # YAML Structure:
  #   Name: "Graph Name"
  #   Constants:
  #     admin_email: "admin@example.com"
  #     base_path: "/tmp"
  #   Graph:
  #     - Name: "mymonitor"
  #       Type: "monitor"
  #       Class: "CGE::FileUpdateMonitor"
  #       Options:
  #         path: "{{graph.base_path}}/file"
  #         frequency: 5
  #     - Name: "myaction"
  #       Type: "action"
  #       Class: "CGE::EmailAction"
  #       Options:
  #         to: "{{graph.admin_email}}"
  #
  # @example
  #   graph = YAMLCommandGraph.new("/path/to/config.yml")
  #   graph.name # => "My Command Graph"
  #   graph.execute
  class YAMLCommandGraph < CommandGraph
    attr_reader :name

    # @param file_path [String] Path to YAML configuration file
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    def initialize(file_path, global_configuration = nil)
      configuration = YAML.load_file(file_path)
      @name = configuration['Name']
      command_list = configuration['Graph']
      constants = configuration['Constants'] || {}

      current_command = nil
      command_list.reverse.each do |command_data|
        command = command_from_data(command_data, current_command)
        current_command = command
      end
      super(current_command, global_configuration, constants)
    end

    def get_class(class_name)
      Object.const_get(class_name)
    rescue StandardError
      raise CommandGraphException, 'Invalid Action, Monitor, or Input type'
    end

    def command_from_data(command_data, next_command)
      name = command_data['Name']
      obj_class = get_class(command_data['Class'])
      options = command_data['Options'] || {}
      obj_class.new(name, options, next_command)
    end

    private :command_from_data, :get_class
  end
end
