require 'spec_helper'
require 'pg'
require 'cge/storage_backends/postgres_storage_backend'
require 'cge/storage_backend'
require 'cge/command'

describe CGE::PostgresStorageBackend do
  let(:connection_params) do
    {
      host: 'localhost',
      port: 5432,
      dbname: 'cge_test',
      user: 'postgres',
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

  let(:mock_database) { instance_double('PG::Connection') }

  before do
    allow(PG).to receive(:connect).and_return(mock_database)
    allow(mock_database).to receive(:exec)
    allow(mock_database).to receive(:exec_params)
    
    # Mock schema version check to avoid upgrade during initialization by default
    # Individual tests can override this by calling expect() instead of allow()
    default_result = double('PG::Result')
    allow(default_result).to receive(:ntuples).and_return(1)
    allow(default_result).to receive(:[]).with(0).and_return({ 'value' => '1' })
    allow(mock_database).to receive(:exec_params).with(
      'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
    ).and_return(default_result)
  end

  describe '#upgrade_if_needed' do
    context 'when schema version is SCHEMA_VERSION_NONE' do
      it 'creates the graphs table' do
        # Override the default mock for this test - need to handle multiple calls
        none_result = double('PG::Result')
        allow(none_result).to receive(:ntuples).and_return(0)
        
        # First call from schema_version method in upgrade_if_needed
        expect(mock_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(none_result).ordered
        
        expect(mock_database).to receive(:exec).with(include('CREATE TABLE graphs')).ordered
        expect(mock_database).to receive(:exec).with(include('CREATE TABLE commands')).ordered
        expect(mock_database).to receive(:exec).with(include('CREATE TABLE config')).ordered
        
        # Second call from update_schema_version method
        expect(mock_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(none_result).ordered
        
        expect(mock_database).to receive(:exec_params).with(
          'INSERT INTO config (key, value) VALUES ($1,$2)', [described_class::SCHEMA_VERSION_KEY, 1]
        ).ordered

        storage_backend.send(:upgrade_if_needed)
      end
    end

    context 'when schema version is current' do
      it 'does not create tables' do
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_CURRENT)
        expect(mock_database).not_to receive(:exec).with(include('CREATE TABLE'))

        storage_backend.send(:upgrade_if_needed)
      end
    end
  end

  describe '#create_or_update_graph' do
    it 'stores commands and graph data' do
      # Mock command operations
      empty_result = double('PG::Result')
      allow(empty_result).to receive(:ntuples).and_return(0)
      
      expect(mock_database).to receive(:exec_params).with(
        'SELECT id FROM commands WHERE id=$1', ['cmd_1']
      ).and_return(empty_result)

      expect(mock_database).to receive(:exec_params).with(
        'INSERT INTO commands (id, name, class, previous_command_id, inputs) VALUES ($1,$2,$3,$4,$5)',
        ['cmd_1', 'test_command', 'TestCommand', nil, '{"param":"value"}']
      )

      # Mock graph operations
      expect(mock_database).to receive(:exec_params).with(
        'SELECT id FROM graphs WHERE id=$1', ['graph_1']
      ).and_return(empty_result)

      expect(mock_database).to receive(:exec_params).with(
        'INSERT INTO graphs (id, name, final_command_id, constants) VALUES ($1,$2,$3,$4)',
        ['graph_1', 'Test Graph', 'cmd_1', '{"const_key":"const_value"}']
      )

      storage_backend.create_or_update_graph(mock_graph)
    end

    it 'updates existing commands and graphs' do
      # Mock command operations
      result_double = double('PG::Result')
      allow(result_double).to receive(:ntuples).and_return(1)

      expect(mock_database).to receive(:exec_params).with(
        'SELECT id FROM commands WHERE id=$1', ['cmd_1']
      ).and_return(result_double)

      expect(mock_database).to receive(:exec_params).with(
        'UPDATE commands SET name=$1, class=$2, previous_command_id=$3, inputs=$4 WHERE id=$5',
        ['test_command', 'TestCommand', nil, '{"param":"value"}', 'cmd_1']
      )

      # Mock graph operations
      expect(mock_database).to receive(:exec_params).with(
        'SELECT id FROM graphs WHERE id=$1', ['graph_1']
      ).and_return(result_double)

      expect(mock_database).to receive(:exec_params).with(
        'UPDATE graphs SET name=$1, final_command_id=$2, constants=$3 WHERE id=$4',
        ['Test Graph', 'cmd_1', '{"const_key":"const_value"}', 'graph_1']
      )

      storage_backend.create_or_update_graph(mock_graph)
    end
  end

  describe '#fetch_graph_with_id' do
    it 'retrieves and builds command graph' do
      # Mock graph query
      graph_result = double('PG::Result')
      allow(graph_result).to receive(:ntuples).and_return(1)
      allow(graph_result).to receive(:[]).with(0).and_return({
                                                               'name' => 'Test Graph',
                                                               'final_command_id' => 'cmd_1',
                                                               'constants' => '{"const_key":"const_value"}'
                                                             })

      expect(mock_database).to receive(:exec_params).with(
        'SELECT name, final_command_id, constants FROM graphs WHERE id=$1', ['graph_1']
      ).and_return(graph_result)

      # Mock command query
      command_result = double('PG::Result')
      allow(command_result).to receive(:ntuples).and_return(1)
      allow(command_result).to receive(:[]).with(0).and_return({
                                                                 'id' => 'cmd_1',
                                                                 'name' => 'test_command',
                                                                 'class' => 'TestCommand',
                                                                 'previous_command_id' => nil,
                                                                 'inputs' => '{"param":"value"}'
                                                               })

      expect(mock_database).to receive(:exec_params).with(
        'SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=$1', ['cmd_1']
      ).and_return(command_result)

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
      graph_result = double('PG::Result')
      allow(graph_result).to receive(:ntuples).and_return(1)
      allow(graph_result).to receive(:[]).with(0).and_return({ 'final_command_id' => 'cmd_1' })

      expect(mock_database).to receive(:exec_params).with(
        'SELECT final_command_id FROM graphs WHERE id=$1', ['graph_1']
      ).and_return(graph_result)

      # Mock graph deletion
      expect(mock_database).to receive(:exec_params).with(
        'DELETE FROM graphs WHERE id=$1', ['graph_1']
      )

      # Mock command cleanup
      command_result = double('PG::Result')
      allow(command_result).to receive(:ntuples).and_return(1)
      allow(command_result).to receive(:[]).with(0).and_return({ 'previous_command_id' => nil })

      expect(mock_database).to receive(:exec_params).with(
        'SELECT previous_command_id FROM commands WHERE id=$1', ['cmd_1']
      ).and_return(command_result)

      expect(mock_database).to receive(:exec_params).with(
        'DELETE FROM commands WHERE id=$1', ['cmd_1']
      )

      storage_backend.delete_graph_with_id('graph_1')
    end
  end

  describe '#schema_version' do
    context 'when schema version exists in config' do
      it 'returns the stored schema version' do
        result = double('PG::Result')
        allow(result).to receive(:ntuples).and_return(1)
        allow(result).to receive(:[]).with(0).and_return({ 'value' => '1' })

        expect(mock_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(result)

        version = storage_backend.send(:schema_version)
        expect(version).to eq(1)
      end
    end

    context 'when schema version does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        # Create completely fresh mocks for this test
        fresh_database = double('PG::Connection')
        
        allow(PG).to receive(:connect).and_return(fresh_database)
        allow(fresh_database).to receive(:exec)
        
        # Setup for initialization - need to handle the upgrade sequence
        init_result = double('PG::Result')
        allow(init_result).to receive(:ntuples).and_return(0)
        
        # First call during upgrade_if_needed -> schema_version
        allow(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(init_result)
        
        # The upgrade will also call update_schema_version which does INSERT
        allow(fresh_database).to receive(:exec_params).with(
          'INSERT INTO config (key, value) VALUES ($1,$2)', [described_class::SCHEMA_VERSION_KEY, 1]
        )
        
        # Create fresh backend (this triggers upgrade)
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Now set up test-specific expectations
        result = double('PG::Result')
        allow(result).to receive(:ntuples).and_return(0)
        
        expect(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(result)

        version = fresh_backend.send(:schema_version)
        expect(version).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end

    context 'when table does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        # Create completely fresh mocks for this test
        fresh_database = double('PG::Connection')
        
        allow(PG).to receive(:connect).and_return(fresh_database)
        allow(fresh_database).to receive(:exec)
        
        # Setup for initialization (let the first call succeed, then fail on test call)
        init_result = double('PG::Result')
        allow(init_result).to receive(:ntuples).and_return(1)
        allow(init_result).to receive(:[]).with(0).and_return({ 'value' => '1' })
        allow(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(init_result)
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Now set up test-specific expectations 
        expect(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_raise(PG::UndefinedTable.new('table does not exist'))

        version = fresh_backend.send(:schema_version)
        expect(version).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end
  end

  describe '#update_schema_version' do
    context 'when schema version record exists' do
      it 'updates the existing record' do
        # Create a fresh backend instance for this test to avoid constructor issues
        fresh_mock_database = instance_double('PG::Connection')
        allow(PG).to receive(:connect).and_return(fresh_mock_database)
        
        # Mock the initialization calls
        allow(fresh_mock_database).to receive(:exec)
        init_result = double('PG::Result')
        allow(init_result).to receive(:ntuples).and_return(1)
        allow(init_result).to receive(:[]).with(0).and_return({ 'value' => '1' })
        allow(fresh_mock_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(init_result)
        
        # Create backend (this will call constructor)
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Now set up the test-specific mocks
        result = double('PG::Result')
        allow(result).to receive(:ntuples).and_return(1)

        expect(fresh_mock_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(result)

        expect(fresh_mock_database).to receive(:exec_params).with(
          'UPDATE config SET value=$1 WHERE key=$2', [2, described_class::SCHEMA_VERSION_KEY]
        )

        fresh_backend.send(:update_schema_version, 2)
      end
    end

    context 'when schema version record does not exist' do
      it 'inserts a new record' do
        # Create completely fresh mocks for this test
        fresh_database = double('PG::Connection')
        
        allow(PG).to receive(:connect).and_return(fresh_database)
        allow(fresh_database).to receive(:exec)
        
        # Setup for initialization
        init_result = double('PG::Result')
        allow(init_result).to receive(:ntuples).and_return(1)
        allow(init_result).to receive(:[]).with(0).and_return({ 'value' => '1' })
        allow(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(init_result)
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Now set up test-specific expectations
        result = double('PG::Result')
        allow(result).to receive(:ntuples).and_return(0)

        expect(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(result)

        expect(fresh_database).to receive(:exec_params).with(
          'INSERT INTO config (key, value) VALUES ($1,$2)', [described_class::SCHEMA_VERSION_KEY, 2]
        )

        fresh_backend.send(:update_schema_version, 2)
      end
    end
  end

  describe '#list_all_graph_ids' do
    context 'with no graphs' do
      it 'returns empty array' do
        # Create completely fresh mocks for this test
        fresh_database = double('PG::Connection')
        
        allow(PG).to receive(:connect).and_return(fresh_database)
        allow(fresh_database).to receive(:exec)
        
        # Setup for initialization
        init_result = double('PG::Result')
        allow(init_result).to receive(:ntuples).and_return(1)
        allow(init_result).to receive(:[]).with(0).and_return({ 'value' => '1' })
        allow(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(init_result)
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Mock the list query
        empty_result = double('PG::Result')
        allow(empty_result).to receive(:ntuples).and_return(0)
        expect(fresh_database).to receive(:exec_params).with('SELECT id FROM graphs').and_return(empty_result)
        
        graph_ids = fresh_backend.list_all_graph_ids
        expect(graph_ids).to eq([])
      end
    end

    context 'with stored graphs' do
      it 'returns all graph IDs' do
        # Create completely fresh mocks for this test
        fresh_database = double('PG::Connection')
        
        allow(PG).to receive(:connect).and_return(fresh_database)
        allow(fresh_database).to receive(:exec)
        
        # Setup for initialization
        init_result = double('PG::Result')
        allow(init_result).to receive(:ntuples).and_return(1)
        allow(init_result).to receive(:[]).with(0).and_return({ 'value' => '1' })
        allow(fresh_database).to receive(:exec_params).with(
          'SELECT value FROM config WHERE key=$1', [described_class::SCHEMA_VERSION_KEY]
        ).and_return(init_result)
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_params, global_config)
        
        # Mock the list query with results
        list_result = double('PG::Result')
        allow(list_result).to receive(:ntuples).and_return(2)
        allow(list_result).to receive(:[]).with(0).and_return({ 'id' => 'graph_1' })
        allow(list_result).to receive(:[]).with(1).and_return({ 'id' => 'graph_2' })
        expect(fresh_database).to receive(:exec_params).with('SELECT id FROM graphs').and_return(list_result)
        
        graph_ids = fresh_backend.list_all_graph_ids
        expect(graph_ids).to contain_exactly('graph_1', 'graph_2')
      end
    end
  end
end
