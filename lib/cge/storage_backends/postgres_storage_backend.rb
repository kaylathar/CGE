require 'json'
require 'pg'
require 'cge/storage_backend'
require 'cge/command_graph'
require 'cge/command'

module CGE
  # PostgreSQL storage backend
  class PostgresStorageBackend < StorageBackend
    SCHEMA_VERSION_KEY = 'schema_version'.freeze
    SCHEMA_VERSION_NONE = -1
    SCHEMA_VERSION_CURRENT = 1

    def initialize(connection_params, global_configuration = nil)
      super()
      @connection_params = connection_params
      @global_configuration = global_configuration
      @database = PG.connect(connection_params)
      upgrade_if_needed
    end

    def upgrade_if_needed
      case schema_version
      when SCHEMA_VERSION_NONE
        @database.exec <<-SQL
        CREATE TABLE graphs (
          id VARCHAR(255) PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          final_command_id VARCHAR(255) NOT NULL,
          constants TEXT NOT NULL DEFAULT '{}')
        SQL
        @database.exec <<-SQL
        CREATE TABLE commands (
          id VARCHAR(255) PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          class VARCHAR(255) NOT NULL,
          previous_command_id VARCHAR(255),
          inputs TEXT NOT NULL DEFAULT '{}')
        SQL
        @database.exec <<-SQL
        CREATE TABLE config (
          key VARCHAR(255) PRIMARY KEY,
          value VARCHAR(255) NOT NULL)
        SQL
        update_schema_version(SCHEMA_VERSION_CURRENT)
      end
    end

    def create_or_update_graph(graph)
      previous_command_id = nil
      command = graph.initial_command
      until command.nil?
        result = @database.exec_params('SELECT id FROM commands WHERE id=$1', [command.id])
        if result.ntuples > 0
          @database.exec_params('UPDATE commands SET name=$1, class=$2, previous_command_id=$3, inputs=$4 WHERE id=$5',
                                [command.name, command.class.name, previous_command_id, command.inputs.to_json,
                                 command.id])
        else
          @database.exec_params('INSERT INTO commands (id, name, class, previous_command_id, inputs) VALUES ($1,$2,$3,$4,$5)',
                                [command.id, command.name, command.class.name, previous_command_id,
                                 command.inputs.to_json])
        end
        previous_command_id = command.id
        command = command.next_command
      end

      result = @database.exec_params('SELECT id FROM graphs WHERE id=$1', [graph.id])
      if result.ntuples > 0
        @database.exec_params('UPDATE graphs SET name=$1, final_command_id=$2, constants=$3 WHERE id=$4',
                              [graph.name, previous_command_id, graph.constants.to_json, graph.id])
      else
        @database.exec_params('INSERT INTO graphs (id, name, final_command_id, constants) VALUES ($1,$2,$3,$4)',
                              [graph.id, graph.name, previous_command_id, graph.constants.to_json])
      end
    end

    def fetch_graph_with_id(graph_id)
      name = nil
      initial_command_id = nil
      constants = nil
      result = @database.exec_params('SELECT name, final_command_id, constants FROM graphs WHERE id=$1', [graph_id])
      if result.ntuples > 0
        row = result[0]
        name = row['name']
        initial_command_id = row['final_command_id']
        constants = JSON.parse(row['constants'])
      end

      # Recursively build command graph
      fetch_command_id = initial_command_id
      current_command = nil
      until fetch_command_id.nil?
        result = @database.exec_params('SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=$1',
                                       [fetch_command_id])
        break unless result.ntuples > 0

        row = result[0]
        command_class = Command.safe_const_get(row['class'])
        fetch_command_id = row['previous_command_id']
        current_command = command_class.new(row['id'], row['name'], JSON.parse(row['inputs']), current_command)

      end
      CommandGraph.new(graph_id, name, current_command, @global_configuration, constants)
    end

    def delete_graph_with_id(graph_id)
      # Get final command ID before deleting graph
      result = @database.exec_params('SELECT final_command_id FROM graphs WHERE id=$1', [graph_id])
      final_command_id = result.ntuples > 0 ? result[0]['final_command_id'] : nil

      # Delete graph
      @database.exec_params('DELETE FROM graphs WHERE id=$1', [graph_id])

      # Delete associated commands (traverse backwards from final command)
      fetch_command_id = final_command_id
      until fetch_command_id.nil?
        result = @database.exec_params('SELECT previous_command_id FROM commands WHERE id=$1', [fetch_command_id])
        break if result.ntuples.zero?

        previous_command_id = result[0]['previous_command_id']

        # Delete current command
        @database.exec_params('DELETE FROM commands WHERE id=$1', [fetch_command_id])

        fetch_command_id = previous_command_id
      end
    end

    private

    def schema_version
      result = @database.exec_params('SELECT value FROM config WHERE key=$1', [SCHEMA_VERSION_KEY])
      return result[0]['value'].to_i if result.ntuples > 0

      SCHEMA_VERSION_NONE
    rescue PG::UndefinedTable
      # Table doesn't exist yet - this is a fresh database
      SCHEMA_VERSION_NONE
    end

    def update_schema_version(version)
      result = @database.exec_params('SELECT value FROM config WHERE key=$1', [SCHEMA_VERSION_KEY])
      if result.ntuples > 0
        @database.exec_params('UPDATE config SET value=$1 WHERE key=$2', [version, SCHEMA_VERSION_KEY])
      else
        @database.exec_params('INSERT INTO config (key, value) VALUES ($1,$2)', [SCHEMA_VERSION_KEY, version])
      end
    end
  end
end
