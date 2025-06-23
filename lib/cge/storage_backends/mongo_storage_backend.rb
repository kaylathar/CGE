require 'json'
require 'mongo'
require 'cge/storage_backend'
require 'cge/command_graph'
require 'cge/command'

module CGE
  # MongoDB storage backend
  class MongoStorageBackend < StorageBackend
    SCHEMA_VERSION_KEY = 'schema_version'.freeze
    SCHEMA_VERSION_NONE = -1
    SCHEMA_VERSION_CURRENT = 1

    def initialize(connection_string, database_name, global_configuration = nil)
      super()
      @connection_string = connection_string
      @database_name = database_name
      @global_configuration = global_configuration

      @client = Mongo::Client.new(connection_string)
      @database = @client.use(database_name)
      @graphs_collection = @database[:graphs]
      @commands_collection = @database[:commands]
      @config_collection = @database[:config]

      upgrade_if_needed
    end

    def upgrade_if_needed
      case schema_version
      when SCHEMA_VERSION_NONE
        # Create indexes for better performance
        @graphs_collection.indexes.create_one({ id: 1 }, { unique: true })
        @commands_collection.indexes.create_one({ id: 1 }, { unique: true })
        @commands_collection.indexes.create_one({ graph_id: 1 })
        @config_collection.indexes.create_one({ key: 1 }, { unique: true })

        update_schema_version(SCHEMA_VERSION_CURRENT)
      end
    end

    def create_or_update_graph(graph)
      # Store commands as embedded documents with the graph
      commands_data = []
      previous_command_id = nil
      command = graph.initial_command

      until command.nil?
        command_data = {
          'id' => command.id,
          'name' => command.name,
          'class' => command.class.name,
          'previous_command_id' => previous_command_id,
          'inputs' => command.inputs
        }
        commands_data << command_data

        # Also store individual command documents for easier querying
        @commands_collection.replace_one(
          { 'id' => command.id },
          {
            'id' => command.id,
            'name' => command.name,
            'class' => command.class.name,
            'previous_command_id' => previous_command_id,
            'inputs' => command.inputs,
            'graph_id' => graph.id
          },
          { upsert: true }
        )

        previous_command_id = command.id
        command = command.next_command
      end

      # Store the graph with embedded commands
      graph_document = {
        'id' => graph.id,
        'name' => graph.name,
        'final_command_id' => previous_command_id,
        'constants' => graph.constants,
        'commands' => commands_data,
        'created_at' => Time.now,
        'updated_at' => Time.now
      }

      @graphs_collection.replace_one(
        { 'id' => graph.id },
        graph_document,
        { upsert: true }
      )
    end

    def fetch_graph_with_id(graph_id)
      graph_doc = @graphs_collection.find({ 'id' => graph_id }).first
      return nil unless graph_doc

      name = graph_doc['name']
      final_command_id = graph_doc['final_command_id']
      constants = graph_doc['constants']

      # Build command chain from embedded commands
      commands_by_id = {}
      graph_doc['commands'].each do |cmd_data|
        commands_by_id[cmd_data['id']] = cmd_data
      end

      # Recursively build command graph
      fetch_command_id = final_command_id
      current_command = nil

      until fetch_command_id.nil?
        command_data = commands_by_id[fetch_command_id]
        break unless command_data

        command_class = Command.safe_const_get(command_data['class'])
        fetch_command_id = command_data['previous_command_id']
        current_command = command_class.new(
          command_data['id'],
          command_data['name'],
          command_data['inputs'],
          current_command
        )
      end

      CommandGraph.new(graph_id, name, current_command, @global_configuration, constants)
    end

    def delete_graph_with_id(graph_id)
      # Delete the graph document
      @graphs_collection.delete_one({ 'id' => graph_id })

      # Delete associated command documents
      @commands_collection.delete_many({ 'graph_id' => graph_id })
    end

    def list_all_graph_ids
      @graphs_collection.find({}, projection: { 'id' => 1 }).map { |doc| doc['id'] }
    end

    # Additional MongoDB-specific methods for querying
    def find_graphs_by_name(name_pattern)
      @graphs_collection.find({ 'name' => { '$regex' => name_pattern, '$options' => 'i' } }).to_a
    end

    def find_commands_by_class(class_name)
      @commands_collection.find({ 'class' => class_name }).to_a
    end

    def graph_statistics
      {
        total_graphs: @graphs_collection.count_documents({}),
        total_commands: @commands_collection.count_documents({}),
        graphs_by_name: @graphs_collection.aggregate([
                                                       { '$group' => { '_id' => '$name', 'count' => { '$sum' => 1 } } }
                                                     ]).to_a,
        commands_by_class: @commands_collection.aggregate([
                                                            { '$group' => { '_id' => '$class',
                                                                            'count' => { '$sum' => 1 } } }
                                                          ]).to_a
      }
    end

    private

    def schema_version
      config_doc = @config_collection.find({ 'key' => SCHEMA_VERSION_KEY }).first
      config_doc ? config_doc['value'].to_i : SCHEMA_VERSION_NONE
    rescue StandardError
      # Collection doesn't exist yet
      SCHEMA_VERSION_NONE
    end

    def update_schema_version(version)
      @config_collection.replace_one(
        { 'key' => SCHEMA_VERSION_KEY },
        { 'key' => SCHEMA_VERSION_KEY, 'value' => version, 'updated_at' => Time.now },
        { upsert: true }
      )
    end
  end
end
