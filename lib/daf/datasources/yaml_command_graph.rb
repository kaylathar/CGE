require 'yaml'
require 'daf/command_graph'

module DAF
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
  #       Class: "DAF::FileUpdateMonitor"
  #       Options:
  #         path: "{{graph.base_path}}/file"
  #         frequency: 5
  #     - Name: "myaction"
  #       Type: "action"
  #       Class: "DAF::EmailAction"
  #       Options:
  #         to: "{{graph.admin_email}}"
  #
  # @example
  #   graph = YAMLCommandGraph.new("/path/to/config.yml")
  #   graph.name # => "My Command Graph"
  #   graph.execute
  class YAMLCommandGraph < CommandGraph
    attr_reader :name

    # A graph node that is parsed out of a YAML file
    #
    # Represents a single node in the command graph, instantiated
    # from YAML configuration data. Handles dynamic class loading
    # and proper node linking.
    class YAMLGraphNode < CommandGraphNode
      # @param node_data [Hash] YAML node configuration
      # @param next_node [YAMLGraphNode, nil] Next node in the chain
      def initialize(node_data, next_node)
        raise CommandGraphException, 'Node Name is required' unless node_data['Name']

        name = node_data['Name']
        type = node_data['Type'].to_sym
        obj_class = get_class(node_data['Class'])
        options = node_data['Options']
        super(underlying: obj_class.new, name: name, type: type, next_node: next_node, options: options)
      end

      # Dynamically loads a class by name
      # @param class_name [String] Fully qualified class name
      # @return [Class] The loaded class
      # @raise [CommandGraphException] If class cannot be found
      def get_class(class_name)
        Object.const_get(class_name)
      rescue StandardError
        raise CommandGraphException, 'Invalid Action, Monitor, or Input type'
      end
    end

    # @param file_path [String] Path to YAML configuration file
    def initialize(file_path)
      configuration = YAML.load_file(file_path)
      @name = configuration['Name']
      node_list = configuration['Graph']
      constants = configuration['Constants'] || {}

      current_node = nil
      node_list.reverse.each do |node_data|
        node = YAMLGraphNode.new(node_data, current_node)
        current_node = node
      end
      super(current_node, constants)
    end
  end
end
