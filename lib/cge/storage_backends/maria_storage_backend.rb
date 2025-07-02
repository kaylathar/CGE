# frozen_string_literal: true

require 'json'
require 'mysql2'
require 'cge/storage_backend'
require 'cge/command_graph'
require 'cge/command'

module CGE
  # MariaDB storage backend
  class MariaStorageBackend < StorageBackend
    SCHEMA_VERSION_KEY = 'schema_version'
    SCHEMA_VERSION_NONE = -1
    SCHEMA_VERSION_CURRENT = 1

    def initialize(connection_params, global_configuration = nil)
      super()
      @connection_params = connection_params
      @global_configuration = global_configuration
      @database = Mysql2::Client.new(connection_params)
      upgrade_if_needed
    end

    def upgrade_if_needed
      case schema_version
      when SCHEMA_VERSION_NONE
        @database.query <<-SQL
        CREATE TABLE graphs (
          id VARCHAR(255) PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          final_command_id VARCHAR(255) NOT NULL,
          constants TEXT NOT NULL DEFAULT '{}')
        SQL
        @database.query <<-SQL
        CREATE TABLE commands (
          id VARCHAR(255) PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          class VARCHAR(255) NOT NULL,
          previous_command_id VARCHAR(255),
          inputs TEXT NOT NULL DEFAULT '{}')
        SQL
        @database.query <<-SQL
        CREATE TABLE config (
          `key` VARCHAR(255) PRIMARY KEY,
          `value` VARCHAR(255) NOT NULL)
        SQL
        update_schema_version(SCHEMA_VERSION_CURRENT)
      end
    end

    def create_or_update_graph(graph)
      previous_command_id = nil
      command = graph.initial_command
      until command.nil?
        stmt = @database.prepare('SELECT id FROM commands WHERE id=?')
        result = stmt.execute(command.id)
        if result.any?
          stmt = @database.prepare('UPDATE commands SET name=?, class=?, previous_command_id=?, inputs=? WHERE id=?')
          stmt.execute(command.name, command.class.name, previous_command_id, command.inputs.to_json, command.id)
        else
          stmt = @database.prepare('INSERT INTO commands (id, name, class, previous_command_id, inputs) VALUES (?,?,?,?,?)')
          stmt.execute(command.id, command.name, command.class.name, previous_command_id, command.inputs.to_json)
        end
        previous_command_id = command.id
        command = command.next_command
      end

      stmt = @database.prepare('SELECT id FROM graphs WHERE id=?')
      result = stmt.execute(graph.id)
      if result.any?
        stmt = @database.prepare('UPDATE graphs SET name=?, final_command_id=?, constants=? WHERE id=?')
        stmt.execute(graph.name, previous_command_id, graph.constants.to_json, graph.id)
      else
        stmt = @database.prepare('INSERT INTO graphs (id, name, final_command_id, constants) VALUES (?,?,?,?)')
        stmt.execute(graph.id, graph.name, previous_command_id, graph.constants.to_json)
      end
    end

    def fetch_graph_with_id(graph_id)
      name = nil
      initial_command_id = nil
      constants = nil
      stmt = @database.prepare('SELECT name, final_command_id, constants FROM graphs WHERE id=?')
      result = stmt.execute(graph_id)
      result.each do |row|
        name = row['name']
        initial_command_id = row['final_command_id']
        constants = JSON.parse(row['constants'])
      end

      # Recursively build command graph
      fetch_command_id = initial_command_id
      current_command = nil
      until fetch_command_id.nil?
        stmt = @database.prepare('SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=?')
        result = stmt.execute(fetch_command_id)
        result.each do |row|
          command_class = Command.safe_const_get(row['class'])
          fetch_command_id = row['previous_command_id']
          current_command = command_class.new(row['id'], row['name'], JSON.parse(row['inputs']), current_command)
        end
        break if result.none?
      end
      CommandGraph.new(graph_id, name, current_command, @global_configuration, constants)
    end

    def delete_graph_with_id(graph_id)
      # Get final command ID before deleting graph
      stmt = @database.prepare('SELECT final_command_id FROM graphs WHERE id=?')
      result = stmt.execute(graph_id)
      final_command_id = nil
      result.each { |row| final_command_id = row['final_command_id'] }

      # Delete graph
      stmt = @database.prepare('DELETE FROM graphs WHERE id=?')
      stmt.execute(graph_id)

      # Delete associated commands (traverse backwards from final command)
      fetch_command_id = final_command_id
      until fetch_command_id.nil?
        stmt = @database.prepare('SELECT previous_command_id FROM commands WHERE id=?')
        result = stmt.execute(fetch_command_id)
        previous_command_id = nil
        result.each { |row| previous_command_id = row['previous_command_id'] }

        # Delete current command
        stmt = @database.prepare('DELETE FROM commands WHERE id=?')
        stmt.execute(fetch_command_id)

        fetch_command_id = previous_command_id
        break if result.none?
      end
    end

    def list_all_graph_ids
      stmt = @database.prepare('SELECT id FROM graphs')
      result = stmt.execute
      result.map { |row| row['id'] }
    end

    private

    def schema_version
      stmt = @database.prepare('SELECT `value` FROM config WHERE `key`=?')
      result = stmt.execute(SCHEMA_VERSION_KEY)
      result.each { |row| return row['value'].to_i } # rubocop:disable Lint/UnreachableLoop
      SCHEMA_VERSION_NONE
    rescue Mysql2::Error => e
      # Table doesn't exist yet - this is a fresh database
      return SCHEMA_VERSION_NONE if e.message.include?("doesn't exist")

      raise e
    end

    def update_schema_version(version)
      stmt = @database.prepare('SELECT `value` FROM config WHERE `key`=?')
      result = stmt.execute(SCHEMA_VERSION_KEY)
      if result.any?
        stmt = @database.prepare('UPDATE config SET `value`=? WHERE `key`=?')
        stmt.execute(version, SCHEMA_VERSION_KEY)
      else
        stmt = @database.prepare('INSERT INTO config (`key`, `value`) VALUES (?,?)')
        stmt.execute(SCHEMA_VERSION_KEY, version)
      end
    end
  end
end
