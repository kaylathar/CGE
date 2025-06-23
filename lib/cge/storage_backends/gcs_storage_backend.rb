require 'json'
require 'google/cloud/storage'
require 'cge/storage_backend'
require 'cge/command_graph'
require 'cge/command'

module CGE
  # Google Cloud Storage backend
  class GCSStorageBackend < StorageBackend
    SCHEMA_VERSION_KEY = 'schema_version'.freeze
    SCHEMA_VERSION_NONE = -1
    SCHEMA_VERSION_CURRENT = 1

    def initialize(bucket_name, credentials_path = nil, global_configuration = nil)
      super()
      @bucket_name = bucket_name
      @global_configuration = global_configuration

      storage_options = {}
      storage_options[:credentials] = credentials_path if credentials_path
      @storage = Google::Cloud::Storage.new(storage_options)
      @bucket = @storage.bucket(bucket_name)

      raise "Bucket #{bucket_name} not found" unless @bucket

      upgrade_if_needed
    end

    def upgrade_if_needed
      case schema_version
      when SCHEMA_VERSION_NONE
        # Create index files to track graphs and commands
        create_index_file('graphs', {})
        create_index_file('commands', {})
        create_index_file('config', { SCHEMA_VERSION_KEY => SCHEMA_VERSION_CURRENT })
        update_schema_version(SCHEMA_VERSION_CURRENT)
      end
    end

    def create_or_update_graph(graph)
      commands_index = load_index('commands')
      graphs_index = load_index('graphs')

      # Store commands
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

        # Store command as individual file
        file_path = "commands/#{command.id}.json"
        @bucket.create_file(StringIO.new(command_data.to_json), file_path)

        # Update index
        commands_index[command.id] = {
          'name' => command.name,
          'class' => command.class.name,
          'previous_command_id' => previous_command_id
        }

        previous_command_id = command.id
        command = command.next_command
      end

      # Store graph
      graph_data = {
        'id' => graph.id,
        'name' => graph.name,
        'final_command_id' => previous_command_id,
        'constants' => graph.constants
      }

      file_path = "graphs/#{graph.id}.json"
      @bucket.create_file(StringIO.new(graph_data.to_json), file_path)

      # Update indexes
      graphs_index[graph.id] = {
        'name' => graph.name,
        'final_command_id' => previous_command_id
      }

      save_index('commands', commands_index)
      save_index('graphs', graphs_index)
    end

    def fetch_graph_with_id(graph_id)
      # Load graph data
      graph_file = @bucket.file("graphs/#{graph_id}.json")
      return nil unless graph_file

      graph_data = JSON.parse(graph_file.download.string)
      name = graph_data['name']
      initial_command_id = graph_data['final_command_id']
      constants = graph_data['constants']

      # Recursively build command graph
      fetch_command_id = initial_command_id
      current_command = nil
      until fetch_command_id.nil?
        command_file = @bucket.file("commands/#{fetch_command_id}.json")
        break unless command_file

        command_data = JSON.parse(command_file.download.string)
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
      graphs_index = load_index('graphs')
      commands_index = load_index('commands')

      # Delete graph file
      graph_file = @bucket.file("graphs/#{graph_id}.json")
      graph_file.delete if graph_file

      # Find and delete associated commands
      graph_data = graphs_index[graph_id]
      if graph_data
        fetch_command_id = graph_data['final_command_id']
        until fetch_command_id.nil?
          command_file = @bucket.file("commands/#{fetch_command_id}.json")
          break unless command_file

          command_data = JSON.parse(command_file.download.string)
          next_command_id = command_data['previous_command_id']

          # Delete command file and from index
          command_file.delete
          commands_index.delete(fetch_command_id)

          fetch_command_id = next_command_id
        end
      end

      # Remove from graph index
      graphs_index.delete(graph_id)

      save_index('graphs', graphs_index)
      save_index('commands', commands_index)
    end

    private

    def schema_version
      config = load_index('config')
      config[SCHEMA_VERSION_KEY] || SCHEMA_VERSION_NONE
    rescue StandardError
      # Config file doesn't exist yet
      SCHEMA_VERSION_NONE
    end

    def update_schema_version(version)
      config = load_index('config')
      config[SCHEMA_VERSION_KEY] = version
      save_index('config', config)
    end

    def create_index_file(name, initial_data)
      file_path = "indexes/#{name}.json"
      @bucket.create_file(StringIO.new(initial_data.to_json), file_path)
    end

    def load_index(name)
      file_path = "indexes/#{name}.json"
      index_file = @bucket.file(file_path)
      return {} unless index_file

      JSON.parse(index_file.download.string)
    end

    def save_index(name, data)
      file_path = "indexes/#{name}.json"
      # Delete existing file
      existing_file = @bucket.file(file_path)
      existing_file.delete if existing_file

      # Create new file
      @bucket.create_file(StringIO.new(data.to_json), file_path)
    end
  end
end
