require 'json'

module DAF
  # A command graph that is parsed out of a JSON file
  #
  # Loads and constructs a command graph from JSON configuration files.
  # The JSON file should contain a Name and Graph structure defining
  # the sequence of monitors and actions to execute.
  #
  # JSON Structure:
  #   {
  #     "Name": "Graph Name",
  #     "Constants": {
  #       "admin_email": "admin@example.com",
  #       "base_path": "/tmp"
  #     },
  #     "Graph": [
  #       {
  #         "Name": "MyMonitor"
  #         "Type": "monitor",
  #         "Class": "DAF::FileUpdateMonitor",
  #         "Options": {
  #           "path": "{{graph.base_path}}/file",
  #           "frequency": 5
  #         }
  #       },
  #       {
  #         "Name": "MyAction"
  #         "Type": "action",
  #         "Class": "DAF::EmailAction",
  #         "Options": {
  #           "to": "{{graph.admin_email}}"
  #         }
  #       }
  #     ]
  #   }
  #
  # @example
  #   graph = JSONCommandGraph.new("/path/to/config.json")
  #   graph.name # => "My Command Graph"
  #   graph.execute
  class JSONCommandGraph < CommandGraph
    attr_reader :name

    # @param file_path [String] Path to JSON configuration file
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    def initialize(file_path, global_configuration = nil)
      configuration = JSON.parse(File.read(file_path))
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
