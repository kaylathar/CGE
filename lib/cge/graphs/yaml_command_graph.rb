# frozen_string_literal: true

require 'yaml'
require 'securerandom'
require 'cge/command_graph'
require 'cge/command'

module CGE
  # A command graph that is parsed out of a YAML file
  #
  # Loads and constructs a command graph from YAML configuration files.
  # The YAML file should contain a Name and Graph structure defining
  # the sequence of monitors and actions to execute.
  #
  # YAML Subgraph Structure (required format):
  #   Name: "Graph Name"
  #   StartSubgraphId: "main"
  #   Constants:
  #     admin_email: "admin@example.com"
  #   Subgraphs:
  #     main:
  #       - Name: "Monitor"
  #         Class: "CGE::FileUpdateMonitor"
  #         Inputs: {}
  #       - Name: "Action"
  #         Class: "CGE::EmailAction"
  #         Inputs: {}
  #     alt_flow:
  #       - Name: "AltAction"
  #         Class: "CGE::LogAction"
  #         Inputs: {}
  #
  # @example
  #   graph = YAMLCommandGraph.new("/path/to/config.yml")
  #   graph.name # => "My Command Graph"
  #   graph.execute
  class YAMLCommandGraph < CommandGraph
    # @param file_path [String] Path to YAML file
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param service_manager [ServiceManager] Optional service manager instance
    def self.from_file(file_path, global_configuration = nil, service_manager = nil)
      new(File.read(file_path), global_configuration, service_manager)
    end

    # @param yaml_string [String] YAML string
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param service_manager [ServiceManager] Optional service manager instance
    def initialize(yaml_string, global_configuration = nil, service_manager = nil)
      # Load additional plugins before parsing
      CommandGraph.load_additional_plugins(global_configuration)

      configuration = YAML.safe_load(yaml_string)
      id = configuration['Id']
      name = configuration['Name']
      constants = configuration['Constants'] || {}

      subgraphs = {}
      initial_subgraph_id = configuration['StartSubgraphId']

      configuration['Subgraphs'].each do |subgraph_id, command_list|
        current_command = nil
        command_list.reverse.each do |command_data|
          command = command_from_data(command_data, current_command, service_manager)
          current_command = command
        end
        subgraphs[subgraph_id] = current_command
      end

      super(id, name, subgraphs, initial_subgraph_id, global_configuration, constants, nil, configuration.key?('Repeat'))
    end

    def get_class(class_name)
      Command.safe_const_get(class_name)
    rescue SecurityError, StandardError
      raise CommandGraphException, 'Invalid Action, Monitor, or Input type'
    end

    def command_from_data(command_data, next_command, service_manager = nil)
      name = command_data['Name']
      obj_class = get_class(command_data['Class'])
      inputs = command_data['Inputs'] || command_data['Options'] || {}
      id = command_data['Id'] || SecureRandom.uuid
      obj_class.new(id, name, inputs, next_command, nil, service_manager)
    end

    private :command_from_data, :get_class
  end
end
