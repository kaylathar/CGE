require 'spec_helper'
require 'mysql2'
require 'cge/storage_backends/maria_storage_backend'
require 'cge/storage_backend'
require 'cge/command'

describe CGE::MariaStorageBackend do
  let(:connection_params) do
    {
      host: 'localhost',
      port: 3306,
      database: 'cge_test',
      username: 'root',
      password: 'password'
    }
  end
  let(:global_config) { instance_double('GlobalConfiguration') }
  let(:storage_backend) { described_class.new(connection_params, global_config) }

  # Mock command class for testing
  class TestCommand < CGE::Command
    def initialize(id, name, inputs = {}, previous_command = nil)
      super
    end

    def invoke(_inputs)
      { result: 'test_output' }
    end
  end

  # Mock command graph for testing
  let(:mock_command) do
    cmd = TestCommand.new('cmd_1', 'test_command', { 'param' => 'value' })
    allow(cmd).to receive(:next_command).and_return(nil)
    allow(cmd).to receive(:class).and_return(TestCommand)
    allow(cmd).to receive(:inputs).and_return({ 'param' => 'value' })
    cmd
  end

  let(:mock_graph) do
    graph = instance_double('CommandGraph')
    allow(graph).to receive(:id).and_return('graph_1')
    allow(graph).to receive(:name).and_return('Test Graph')
    allow(graph).to receive(:initial_command).and_return(mock_command)
    allow(graph).to receive(:constants).and_return({ 'const_key' => 'const_value' })
    graph
  end

  let(:mock_database) { instance_double('Mysql2::Client') }
  let(:mock_statement) { instance_double('Mysql2::Statement') }
  let(:mock_result) { instance_double('Mysql2::Result') }

  before do
    allow(Mysql2::Client).to receive(:new).and_return(mock_database)
    allow(mock_database).to receive(:query)
    allow(mock_database).to receive(:prepare).and_return(mock_statement)
    allow(mock_statement).to receive(:execute).and_return(mock_result)
    allow(mock_result).to receive(:count).and_return(0)
    # Default to yielding a current schema version to avoid upgrade during initialization
    allow(mock_result).to receive(:each).and_yield({ 'value' => '1' })
  end

  describe '#upgrade_if_needed' do
    context 'when schema version is SCHEMA_VERSION_NONE' do
      it 'creates the database tables' do
        expect(mock_database).to receive(:query).with(include('CREATE TABLE graphs'))
        expect(mock_database).to receive(:query).with(include('CREATE TABLE commands'))
        expect(mock_database).to receive(:query).with(include('CREATE TABLE config'))

        # Mock schema version and update calls
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_NONE)
        allow(storage_backend).to receive(:update_schema_version)

        storage_backend.send(:upgrade_if_needed)
      end
    end

    context 'when schema version is current' do
      it 'does not create tables' do
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_CURRENT)
        expect(mock_database).not_to receive(:query).with(include('CREATE TABLE'))

        storage_backend.send(:upgrade_if_needed)
      end
    end
  end

  describe '#create_or_update_graph' do
    it 'stores commands and graph data for new records' do
      # Mock command operations
      allow(mock_result).to receive(:count).and_return(0)

      expect(mock_database).to receive(:prepare).with('SELECT id FROM commands WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('cmd_1').and_return(mock_result)

      expect(mock_database).to receive(:prepare).with('INSERT INTO commands (id, name, class, previous_command_id, inputs) VALUES (?,?,?,?,?)').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('cmd_1', 'test_command', 'TestCommand', nil, '{"param":"value"}')

      # Mock graph operations
      expect(mock_database).to receive(:prepare).with('SELECT id FROM graphs WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('graph_1').and_return(mock_result)

      expect(mock_database).to receive(:prepare).with('INSERT INTO graphs (id, name, final_command_id, constants) VALUES (?,?,?,?)').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('graph_1', 'Test Graph', 'cmd_1', '{"const_key":"const_value"}')

      storage_backend.create_or_update_graph(mock_graph)
    end

    it 'updates existing commands and graphs' do
      # Mock command operations
      allow(mock_result).to receive(:count).and_return(1)

      expect(mock_database).to receive(:prepare).with('SELECT id FROM commands WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('cmd_1').and_return(mock_result)

      expect(mock_database).to receive(:prepare).with('UPDATE commands SET name=?, class=?, previous_command_id=?, inputs=? WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('test_command', 'TestCommand', nil, '{"param":"value"}', 'cmd_1')

      # Mock graph operations
      expect(mock_database).to receive(:prepare).with('SELECT id FROM graphs WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('graph_1').and_return(mock_result)

      expect(mock_database).to receive(:prepare).with('UPDATE graphs SET name=?, final_command_id=?, constants=? WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('Test Graph', 'cmd_1', '{"const_key":"const_value"}', 'graph_1')

      storage_backend.create_or_update_graph(mock_graph)
    end
  end

  describe '#fetch_graph_with_id' do
    it 'retrieves and builds command graph' do
      # Mock graph query with separate objects
      graph_statement = double('Mysql2::Statement')
      graph_result = double('Mysql2::Result')
      expect(mock_database).to receive(:prepare).with('SELECT name, final_command_id, constants FROM graphs WHERE id=?').and_return(graph_statement)
      expect(graph_statement).to receive(:execute).with('graph_1').and_return(graph_result)
      expect(graph_result).to receive(:each).and_yield({
                                                        'name' => 'Test Graph',
                                                        'final_command_id' => 'cmd_1',
                                                        'constants' => '{"const_key":"const_value"}'
                                                      })

      # Mock command query with separate objects  
      command_statement = double('Mysql2::Statement')
      command_result = double('Mysql2::Result')
      expect(mock_database).to receive(:prepare).with('SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=?').and_return(command_statement)
      expect(command_statement).to receive(:execute).with('cmd_1').and_return(command_result)
      expect(command_result).to receive(:each).and_yield({
                                                        'id' => 'cmd_1',
                                                        'name' => 'test_command',
                                                        'class' => 'TestCommand',
                                                        'previous_command_id' => nil,
                                                        'inputs' => '{"param":"value"}'
                                                      })
      allow(command_result).to receive(:count).and_return(1)

      allow(CGE::Command).to receive(:safe_const_get).and_call_original
      allow(CGE::Command).to receive(:safe_const_get).with('TestCommand').and_return(TestCommand)
      expect(CGE::CommandGraph).to receive(:new).with(
        'graph_1', 'Test Graph', anything, global_config, { 'const_key' => 'const_value' }
      )

      storage_backend.fetch_graph_with_id('graph_1')
    end
  end

  describe '#delete_graph_with_id' do
    it 'deletes the graph and associated commands from the database' do
      # Mock getting final command ID
      graph_result = double('Mysql2::Result')
      allow(graph_result).to receive(:each).and_yield({ 'final_command_id' => 'cmd_1' })

      expect(mock_database).to receive(:prepare).with('SELECT final_command_id FROM graphs WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('graph_1').and_return(graph_result)

      # Mock graph deletion
      expect(mock_database).to receive(:prepare).with('DELETE FROM graphs WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('graph_1')

      # Mock command cleanup
      command_result = double('Mysql2::Result')
      allow(command_result).to receive(:each).and_yield({ 'previous_command_id' => nil })
      allow(command_result).to receive(:count).and_return(1, 0)

      expect(mock_database).to receive(:prepare).with('SELECT previous_command_id FROM commands WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('cmd_1').and_return(command_result)

      expect(mock_database).to receive(:prepare).with('DELETE FROM commands WHERE id=?').and_return(mock_statement)
      expect(mock_statement).to receive(:execute).with('cmd_1')

      storage_backend.delete_graph_with_id('graph_1')
    end
  end

  describe '#schema_version' do
    context 'when schema version exists in config' do
      it 'returns the stored schema version' do
        expect(mock_database).to receive(:prepare).with('SELECT `value` FROM config WHERE `key`=?').and_return(mock_statement)
        expect(mock_statement).to receive(:execute).with(described_class::SCHEMA_VERSION_KEY).and_return(mock_result)
        expect(mock_result).to receive(:each).and_yield({ 'value' => '1' })

        version = storage_backend.send(:schema_version)
        expect(version).to eq(1)
      end
    end

    context 'when schema version does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        # Create completely fresh mocks for this test
        fresh_database = double('Mysql2::Client')
        fresh_statement = double('Mysql2::Statement')
        fresh_result = double('Mysql2::Result')
        
        allow(Mysql2::Client).to receive(:new).and_return(fresh_database)
        allow(fresh_database).to receive(:query)
        allow(fresh_database).to receive(:prepare).and_return(fresh_statement)
        allow(fresh_statement).to receive(:execute).and_return(fresh_result)
        allow(fresh_result).to receive(:count).and_return(0)
        allow(fresh_result).to receive(:each) # No yield for initialization
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Now set up test-specific expectations
        expect(fresh_database).to receive(:prepare).with('SELECT `value` FROM config WHERE `key`=?').and_return(fresh_statement)
        expect(fresh_statement).to receive(:execute).with(described_class::SCHEMA_VERSION_KEY).and_return(fresh_result)
        expect(fresh_result).to receive(:each) # No yield = returns SCHEMA_VERSION_NONE

        version = fresh_backend.send(:schema_version)
        expect(version).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end

    context 'when table does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        # Create completely fresh mocks for this test
        fresh_database = double('Mysql2::Client')
        fresh_statement = double('Mysql2::Statement')
        fresh_result = double('Mysql2::Result')
        
        allow(Mysql2::Client).to receive(:new).and_return(fresh_database)
        allow(fresh_database).to receive(:query)
        allow(fresh_database).to receive(:prepare).and_return(fresh_statement)
        allow(fresh_statement).to receive(:execute).and_return(fresh_result)
        allow(fresh_result).to receive(:count).and_return(0)
        allow(fresh_result).to receive(:each) # No yield for initialization
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Now set up test-specific expectations
        error = Mysql2::Error.new("Table 'cge_test.config' doesn't exist")
        expect(fresh_database).to receive(:prepare).and_raise(error)

        version = fresh_backend.send(:schema_version)
        expect(version).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end
  end

  describe '#update_schema_version' do
    context 'when schema version record exists' do
      it 'updates the existing record' do
        allow(mock_result).to receive(:count).and_return(1)

        expect(mock_database).to receive(:prepare).with('SELECT `value` FROM config WHERE `key`=?').and_return(mock_statement)
        expect(mock_statement).to receive(:execute).with(described_class::SCHEMA_VERSION_KEY).and_return(mock_result)

        expect(mock_database).to receive(:prepare).with('UPDATE config SET `value`=? WHERE `key`=?').and_return(mock_statement)
        expect(mock_statement).to receive(:execute).with(2, described_class::SCHEMA_VERSION_KEY)

        storage_backend.send(:update_schema_version, 2)
      end
    end

    context 'when schema version record does not exist' do
      it 'inserts a new record' do
        allow(mock_result).to receive(:count).and_return(0)

        expect(mock_database).to receive(:prepare).with('SELECT `value` FROM config WHERE `key`=?').and_return(mock_statement)
        expect(mock_statement).to receive(:execute).with(described_class::SCHEMA_VERSION_KEY).and_return(mock_result)

        expect(mock_database).to receive(:prepare).with('INSERT INTO config (`key`, `value`) VALUES (?,?)').and_return(mock_statement)
        expect(mock_statement).to receive(:execute).with(described_class::SCHEMA_VERSION_KEY, 2)

        storage_backend.send(:update_schema_version, 2)
      end
    end
  end
end
