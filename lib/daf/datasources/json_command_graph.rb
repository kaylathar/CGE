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
  #     "Graph": [
  #       {
  #         "Name": "MyMonitor"
  #         "Type": "monitor",
  #         "Class": "DAF::FileUpdateMonitor",
  #         "Options": {
  #           "path": "/tmp/file",
  #           "frequency": 5
  #         }
  #       },
  #       {
  #         "Name": "MyAction"
  #         "Type": "action",
  #         "Class": "DAF::EmailAction",
  #         "Options": {
  #           "to": "admin@example.com"
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

    # A graph node that is parsed out of a JSON file
    #
    # Represents a single node in the command graph, instantiated
    # from JSON configuration data. Handles dynamic class loading
    # and proper node linking.
    class JSONGraphNode < CommandGraphNode
      # @param node_data [Hash] JSON node configuration
      # @param next_node [JSONGraphNode, nil] Next node in the chain
      def initialize(node_data, next_node)
        raise CommandGraphException, 'Node Name is required' unless node_data['Name']

        name = node_data['Name']
        type = node_data['Type'].to_sym
        obj_class = get_class(node_data['Class'])
        options = node_data['Options'] || {}

        super(underlying: obj_class.new, name: name, type: type, next_node: next_node, options: options)
      end

      # Dynamically loads a class by name
      # @param class_name [String] Fully qualified class name
      # @return [Class] The loaded class
      # @raise [CommandException] If class cannot be found
      def get_class(class_name)
        Object.const_get(class_name)
      rescue StandardError
        raise CommandGraphException, 'Invalid Action or Monitor type'
      end
    end

    # @param file_path [String] Path to JSON configuration file
    def initialize(file_path)
      configuration = JSON.parse(File.read(file_path))
      @name = configuration['Name']
      node_list = configuration['Graph']

      current_node = nil
      node_list.reverse.each do |node_data|
        node = JSONGraphNode.new(node_data, current_node)
        current_node = node
      end

      super(current_node)
    end
  end
end
