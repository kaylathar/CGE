# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'cge/command'

module CGE
  # A command graph that is parsed out of jSON
  #
  # Loads and constructs a command graph from JSON configuration
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
  #         "Class": "CGE::FileUpdateMonitor",
  #         "Inputs": {
  #           "path": "{{graph.base_path}}/file",
  #           "frequency": 5
  #         }
  #       },
  #       {
  #         "Name": "MyAction"
  #         "Class": "CGE::EmailAction",
  #         "Inputs": {
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
    # @param file_path [String] Path to JSON configuration file
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param service_manager [ServiceManager] Optional service manager instance
    def self.from_file(file_path, global_configuration = nil, service_manager = nil)
      new(File.read(file_path), global_configuration, service_manager)
    end

    # @param json_data [String] JSON data to parse command graph from
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param service_manager [ServiceManager] Optional service manager instance
    def initialize(json_data, global_configuration = nil, service_manager = nil)
      # Load additional plugins before parsing
      CommandGraph.load_additional_plugins(global_configuration)

      configuration = JSON.parse(json_data)
      id = configuration['Id']
      name = configuration['Name']
      command_list = configuration['Graph']
      constants = configuration['Constants'] || {}

      current_command = nil
      command_list.reverse.each do |command_data|
        command = command_from_data(command_data, current_command, service_manager)
        current_command = command
      end

      super(id, name, current_command, global_configuration, constants, configuration.key?('Repeat'))
      @repeat = configuration.key?('Repeat')
    end

    def get_class(class_name)
      Command.safe_const_get(class_name)
    rescue SecurityError, StandardError
      raise CommandGraphException, 'Invalid Action, Monitor, or Input type'
    end

    def command_from_data(command_data, next_command, service_manager = nil)
      name = command_data['Name']
      obj_class = get_class(command_data['Class'])
      inputs = command_data['Inputs'] || {}
      id = command_data['Id'] || SecureRandom.uuid
      obj_class.new(id, name, inputs, next_command, nil, service_manager)
    end

    private :command_from_data, :get_class
  end
end
