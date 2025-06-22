require 'json'
require 'sqlite3'
require 'cge/storage_backend'
require 'cge/command_graph'

module CGE
  # SQLite storage backend
  class SQLiteStorageBackend < StorageBackend
    SCHEMA_VERSION_KEY = 'schema_version'.freeze
    SCHEMA_VERSION_NONE = -1
    SCHEMA_VERSION_CURRENT = 1

    def initialize(file_path, global_configuration = nil)
      super()
      @global_configuration = global_configuration
      @database = SQLite3::Database.new(file_path)
      upgrade_if_needed
    end

    def upgrade_if_needed
      case schema_version
      when SCHEMA_VERSION_NONE
        @database.execute <<-SQL
        CREATE TABLE graphs (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          final_command_id TEXT NOT NULL,
          constants TEXT NOT NULL DEFAULT "{}")
        SQL
        @database.execute <<-SQL
        CREATE TABLE commands (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          class TEXT NOT NULL,
          previous_command_id TEXT,
          inputs TEXT NOT NULL DEFAULT "{}")
        SQL
        @database.execute <<-SQL
        CREATE TABLE config (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL)
        SQL
        update_schema_version(SCHEMA_VERSION_CURRENT)
      end
    end

    def create_or_update_graph(graph)
      previous_command_id = nil
      command = graph.initial_command
      until command.nil?
        if @database.execute('SELECT id FROM commands WHERE id=?', [command.id]).count > 0
          @database.execute('UPDATE commands SET name=?, class=?, previous_command_id=?, inputs=? WHERE id=?',
                            [command.name, command.class.name, previous_command_id, command.inputs.to_json, command.id])
        else
          @database.execute('INSERT INTO commands (id, name, class, previous_command_id, inputs) VALUES (?,?,?,?,?)',
                            [command.id, command.name, command.class.name, previous_command_id, command.inputs.to_json])
        end
        previous_command_id = command.id
        command = command.next_command
      end
      if @database.execute('SELECT id FROM graphs WHERE id=?', [graph.id]).count > 0
        @database.execute('UPDATE graphs SET name=?, final_command_id=?, constants=? WHERE id=?',
                          [graph.name, previous_command_id, graph.constants.to_json, graph.id])
      else
        @database.execute('INSERT INTO graphs (id, name, final_command_id, constants) VALUES (?,?,?,?)',
                          [graph.id, graph.name, previous_command_id, graph.constants.to_json])
      end
    end

    def fetch_graph_with_id(graph_id)
      name = nil
      initial_command_id = nil
      constants = nil
      @database.execute('SELECT name, final_command_id, constants FROM graphs WHERE id=?', [graph_id]) do |row|
        name = row[0]
        initial_command_id = row[1]
        constants = JSON.parse(row[2])
      end

      # Recursively build command graph
      fetch_command_id = initial_command_id
      current_command = nil
      until fetch_command_id.nil?
        @database.execute('SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=?',
                          [fetch_command_id]) do |row|
          command_class = Command.safe_const_get(row[2])
          fetch_command_id = row[3]
          current_command = command_class.new(row[0], row[1], JSON.parse(row[4]), current_command)
        end
      end
      CommandGraph.new(graph_id, name, current_command, @global_configuration, constants)
    end

    def delete_graph_with_id(graph_id)
      @database.execute('DELETE FROM graphs WHERE id=?', [graph_id])
    end

    def schema_version
      @database.execute('SELECT value FROM config WHERE key=?', [SCHEMA_VERSION_KEY]) do |row|
        return row[0].to_i
      end
      SCHEMA_VERSION_NONE
    rescue SQLite3::SQLException => e
      # Table doesn't exist yet - this is a fresh database
      return SCHEMA_VERSION_NONE if e.message.include?('no such table')

      raise e
    end

    def update_schema_version(version)
      if @database.execute('SELECT value FROM config WHERE key=?', [SCHEMA_VERSION_KEY]).count > 0
        @database.execute('UPDATE config SET value=? WHERE key=?', [version, SCHEMA_VERSION_KEY])
      else
        @database.execute('INSERT INTO config (key, value) VALUES (?,?)', [SCHEMA_VERSION_KEY, version])
      end
    end

    private :schema_version, :upgrade_if_needed, :update_schema_version
  end
end
