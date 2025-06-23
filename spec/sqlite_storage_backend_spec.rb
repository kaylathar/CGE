require 'spec_helper'
require 'sqlite3'
require 'cge/storage_backends/sqlite_storage_backend'
require 'cge/storage_backend'
require 'tempfile'
require 'fileutils'

describe CGE::SQLiteStorageBackend do
  let(:temp_db_file) { Tempfile.new(['test_db', '.sqlite3']) }
  let(:db_path) { temp_db_file.path }
  let(:global_config) { instance_double('GlobalConfiguration') }
  let(:storage_backend) { described_class.new(db_path, global_config) }

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

  after(:each) do
    temp_db_file.close
    temp_db_file.unlink
  end

  describe '#upgrade_if_needed' do
    context 'when schema version is SCHEMA_VERSION_NONE' do
      it 'creates the graphs table' do
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE graphs')
        )
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE commands')
        )
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE config')
        )
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT value FROM config WHERE key=?', anything
        ).and_return([])
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'INSERT INTO config (key, value) VALUES (?,?)', anything
        )
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_NONE)

        storage_backend.send(:upgrade_if_needed)
      end

      it 'creates the commands table' do
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE graphs')
        )
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE commands')
        )
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE config')
        )
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT value FROM config WHERE key=?', anything
        ).and_return([])
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'INSERT INTO config (key, value) VALUES (?,?)', anything
        )
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_NONE)

        storage_backend.send(:upgrade_if_needed)
      end

      it 'creates the config table' do
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE graphs')
        )
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE commands')
        )
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          include('CREATE TABLE config')
        )
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT value FROM config WHERE key=?', anything
        ).and_return([])
        allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'INSERT INTO config (key, value) VALUES (?,?)', anything
        )
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_NONE)

        storage_backend.send(:upgrade_if_needed)
      end
    end

    context 'when schema version is current' do
      it 'does not create tables' do
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_CURRENT)
        expect(storage_backend.instance_variable_get(:@database)).not_to receive(:execute).with(
          include('CREATE TABLE')
        )

        storage_backend.send(:upgrade_if_needed)
      end
    end
  end

  describe '#create_or_update_graph' do
    before do
      # Ensure tables exist
      storage_backend.send(:upgrade_if_needed)
    end

    context 'when graph does not exist' do
      it 'inserts a new graph record' do
        # Expect command operations first
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT id FROM commands WHERE id=?', ['cmd_1']
        ).and_return([])

        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'INSERT INTO commands (id, name, class, previous_command_id, inputs) VALUES (?,?,?,?,?)',
          ['cmd_1', 'test_command', 'TestCommand', nil, '{"param":"value"}']
        )

        # Then expect graph operations
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT id FROM graphs WHERE id=?', ['graph_1']
        ).and_return([])

        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'INSERT INTO graphs (id, name, final_command_id, constants) VALUES (?,?,?,?)',
          ['graph_1', 'Test Graph', 'cmd_1', '{"const_key":"const_value"}']
        )

        storage_backend.create_or_update_graph(mock_graph)
      end
    end

    context 'when graph exists' do
      it 'attempts to update the existing graph record' do
        # Expect command operations first
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT id FROM commands WHERE id=?', ['cmd_1']
        ).and_return([['cmd_1']])

        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'UPDATE commands SET name=?, class=?, previous_command_id=?, inputs=? WHERE id=?',
          ['test_command', 'TestCommand', nil, '{"param":"value"}', 'cmd_1']
        )

        # Then expect graph operations
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT id FROM graphs WHERE id=?', ['graph_1']
        ).and_return([['graph_1']])

        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'UPDATE graphs SET name=?, final_command_id=?, constants=? WHERE id=?',
          ['Test Graph', 'cmd_1', '{"const_key":"const_value"}', 'graph_1']
        )

        storage_backend.create_or_update_graph(mock_graph)
      end
    end
  end

  describe '#fetch_graph_with_id' do
    before do
      storage_backend.send(:upgrade_if_needed)
    end

    it 'queries the database for graph data' do
      expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
        'SELECT name, final_command_id, constants FROM graphs WHERE id=?', ['graph_1']
      ).and_yield(['Test Graph', 'cmd_1', '{"const_key":"const_value"}'])

      # Mock the command fetching
      expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
        'SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=?', anything
      ).and_yield(['cmd_1', 'test_command', 'TestCommand', nil, '{"param":"value"}'])

      # Mock CommandGraph creation
      expect(CGE::CommandGraph).to receive(:new).with(
        'graph_1', 'Test Graph', anything, global_config, { 'const_key' => 'const_value' }
      )

      storage_backend.fetch_graph_with_id('graph_1')
    end

    it 'handles JSON parsing of constants' do
      allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
        'SELECT name, final_command_id, constants FROM graphs WHERE id=?', ['graph_1']
      ).and_yield(['Test Graph', 'cmd_1', '{"test":"value"}'])

      allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
        'SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=?', anything
      ).and_yield(['cmd_1', 'test_command', 'TestCommand', nil, '{}'])

      expect(CGE::CommandGraph).to receive(:new).with(
        'graph_1', 'Test Graph', anything, global_config, { 'test' => 'value' }
      )

      storage_backend.fetch_graph_with_id('graph_1')
    end

    it 'handles command chain building' do
      allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
        'SELECT name, final_command_id, constants FROM graphs WHERE id=?', ['graph_1']
      ).and_yield(['Test Graph', 'cmd_1', '{}'])

      allow(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
        'SELECT id, name, class, previous_command_id, inputs FROM commands WHERE id=?', anything
      ).and_yield(['cmd_1', 'test_command', 'TestCommand', nil, '{}'])

      allow(Object).to receive(:const_get).and_call_original
      allow(Object).to receive(:const_get).with('TestCommand').and_return(TestCommand)
      expect(CGE::CommandGraph).to receive(:new)

      storage_backend.fetch_graph_with_id('graph_1')
    end
  end

  describe '#delete_graph_with_id' do
    before do
      storage_backend.send(:upgrade_if_needed)
    end

    it 'deletes the graph from the database' do
      expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
        'DELETE FROM graphs WHERE id=?', ['graph_1']
      )

      storage_backend.delete_graph_with_id('graph_1')
    end
  end

  describe '#schema_version' do
    before do
      storage_backend.send(:upgrade_if_needed)
    end

    context 'when schema version exists in config' do
      it 'returns the stored schema version' do
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT value FROM config WHERE key=?', [described_class::SCHEMA_VERSION_KEY]
        ).and_yield(['1'])

        result = storage_backend.send(:schema_version)
        expect(result).to eq(1)
      end
    end

    context 'when schema version does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT value FROM config WHERE key=?', [described_class::SCHEMA_VERSION_KEY]
        ).and_return([])

        result = storage_backend.send(:schema_version)
        expect(result).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end
  end

  describe '#update_schema_version' do
    before do
      storage_backend.send(:upgrade_if_needed)
    end

    context 'when schema version record exists' do
      it 'updates the existing record' do
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT value FROM config WHERE key=?', [described_class::SCHEMA_VERSION_KEY]
        ).and_return([['1']])

        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'UPDATE config SET value=? WHERE key=?', [2, described_class::SCHEMA_VERSION_KEY]
        )

        storage_backend.send(:update_schema_version, 2)
      end
    end

    context 'when schema version record does not exist' do
      it 'inserts a new record' do
        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'SELECT value FROM config WHERE key=?', [described_class::SCHEMA_VERSION_KEY]
        ).and_return([])

        expect(storage_backend.instance_variable_get(:@database)).to receive(:execute).with(
          'INSERT INTO config (key, value) VALUES (?,?)', [described_class::SCHEMA_VERSION_KEY, 2]
        )

        storage_backend.send(:update_schema_version, 2)
      end
    end
  end

  describe '#list_all_graph_ids' do
    context 'with no graphs' do
      it 'returns empty array' do
        graph_ids = storage_backend.list_all_graph_ids
        expect(graph_ids).to eq([])
      end
    end

    context 'with stored graphs' do
      before do
        storage_backend.create_or_update_graph(mock_graph)
        
        # Create a second graph
        second_command = TestCommand.new('cmd_2', 'second_command', { 'param2' => 'value2' })
        allow(second_command).to receive(:next_command).and_return(nil)
        second_graph = instance_double('CommandGraph')
        allow(second_graph).to receive(:id).and_return('graph_2')
        allow(second_graph).to receive(:name).and_return('Second Graph')
        allow(second_graph).to receive(:initial_command).and_return(second_command)
        allow(second_graph).to receive(:constants).and_return({})
        storage_backend.create_or_update_graph(second_graph)
      end

      it 'returns all graph IDs' do
        graph_ids = storage_backend.list_all_graph_ids
        expect(graph_ids).to contain_exactly('graph_1', 'graph_2')
      end
    end
  end
end
