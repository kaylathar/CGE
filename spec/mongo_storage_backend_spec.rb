require 'spec_helper'

begin
  require 'mongo'
  require 'cge/storage_backends/mongo_storage_backend'
rescue LoadError => e
  puts "Skipping MongoStorageBackend tests: #{e.message}"
end

require 'cge/storage_backend'
require 'cge/command'

if defined?(Mongo) && defined?(CGE::MongoStorageBackend)
  RSpec.describe CGE::MongoStorageBackend do
  let(:connection_string) { 'mongodb://localhost:27017' }
  let(:database_name) { 'cge_test' }
  let(:global_config) { instance_double('GlobalConfiguration') }
  let(:storage_backend) { described_class.new(connection_string, database_name, global_config) }

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

  let(:mock_client) { instance_double('Mongo::Client') }
  let(:mock_database) { instance_double('Mongo::Database') }
  let(:mock_graphs_collection) { instance_double('Mongo::Collection') }
  let(:mock_commands_collection) { instance_double('Mongo::Collection') }
  let(:mock_config_collection) { instance_double('Mongo::Collection') }
  let(:mock_indexes) { instance_double('Mongo::Index::View') }

  before do
    allow(Mongo::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:use).and_return(mock_database)
    allow(mock_database).to receive(:[]).with(:graphs).and_return(mock_graphs_collection)
    allow(mock_database).to receive(:[]).with(:commands).and_return(mock_commands_collection)
    allow(mock_database).to receive(:[]).with(:config).and_return(mock_config_collection)

    # Mock indexes
    allow(mock_graphs_collection).to receive(:indexes).and_return(mock_indexes)
    allow(mock_commands_collection).to receive(:indexes).and_return(mock_indexes)
    allow(mock_config_collection).to receive(:indexes).and_return(mock_indexes)
    allow(mock_indexes).to receive(:create_one)

    # Mock collection operations
    allow(mock_graphs_collection).to receive(:replace_one)
    allow(mock_commands_collection).to receive(:replace_one)
    allow(mock_config_collection).to receive(:replace_one)
    allow(mock_graphs_collection).to receive(:find).and_return([])
    allow(mock_commands_collection).to receive(:find).and_return([])
    
    # Default to returning a valid schema version to avoid upgrade during initialization
    default_cursor = double('Mongo::Cursor')
    allow(default_cursor).to receive(:first).and_return({ 'key' => described_class::SCHEMA_VERSION_KEY, 'value' => 1 })
    allow(mock_config_collection).to receive(:find).and_return(default_cursor)
  end

  describe '#upgrade_if_needed' do
    context 'when schema version is SCHEMA_VERSION_NONE' do
      it 'creates indexes' do
        expect(mock_graphs_collection).to receive(:indexes).and_return(mock_indexes)
        expect(mock_indexes).to receive(:create_one).with({ id: 1 }, { unique: true })

        expect(mock_commands_collection).to receive(:indexes).and_return(mock_indexes)
        expect(mock_indexes).to receive(:create_one).with({ id: 1 }, { unique: true })
        expect(mock_indexes).to receive(:create_one).with({ graph_id: 1 })

        expect(mock_config_collection).to receive(:indexes).and_return(mock_indexes)
        expect(mock_indexes).to receive(:create_one).with({ key: 1 }, { unique: true })

        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_NONE)
        allow(storage_backend).to receive(:update_schema_version)

        storage_backend.send(:upgrade_if_needed)
      end
    end

    context 'when schema version is current' do
      it 'does not create indexes' do
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_CURRENT)
        expect(mock_indexes).not_to receive(:create_one)

        storage_backend.send(:upgrade_if_needed)
      end
    end
  end

  describe '#create_or_update_graph' do
    it 'stores commands and graph in MongoDB collections' do
      # Expect command document creation
      expect(mock_commands_collection).to receive(:replace_one).with(
        { 'id' => 'cmd_1' },
        {
          'id' => 'cmd_1',
          'name' => 'test_command',
          'class' => 'TestCommand',
          'previous_command_id' => nil,
          'inputs' => { 'param' => 'value' },
          'graph_id' => 'graph_1'
        },
        { upsert: true }
      )

      # Expect graph document creation with embedded commands
      expect(mock_graphs_collection).to receive(:replace_one) do |filter, document, options|
        expect(filter).to eq({ 'id' => 'graph_1' })
        expect(document['id']).to eq('graph_1')
        expect(document['name']).to eq('Test Graph')
        expect(document['final_command_id']).to eq('cmd_1')
        expect(document['constants']).to eq({ 'const_key' => 'const_value' })
        expect(document['commands'].length).to eq(1)
        expect(document['commands'][0]['id']).to eq('cmd_1')
        expect(options).to eq({ upsert: true })
      end

      storage_backend.create_or_update_graph(mock_graph)
    end
  end

  describe '#fetch_graph_with_id' do
    it 'retrieves and builds command graph from MongoDB' do
      # Mock graph document
      graph_doc = {
        'name' => 'Test Graph',
        'final_command_id' => 'cmd_1',
        'constants' => { 'const_key' => 'const_value' },
        'commands' => [
          {
            'id' => 'cmd_1',
            'name' => 'test_command',
            'class' => 'TestCommand',
            'previous_command_id' => nil,
            'inputs' => { 'param' => 'value' }
          }
        ]
      }

      cursor = double('Mongo::Cursor')
      allow(cursor).to receive(:first).and_return(graph_doc)
      expect(mock_graphs_collection).to receive(:find).with({ 'id' => 'graph_1' }).and_return(cursor)

      allow(CGE::Command).to receive(:safe_const_get).and_call_original
      allow(CGE::Command).to receive(:safe_const_get).with('TestCommand').and_return(TestCommand)
      expect(CGE::CommandGraph).to receive(:new).with(
        'graph_1', 'Test Graph', anything, global_config, { 'const_key' => 'const_value' }
      )

      storage_backend.fetch_graph_with_id('graph_1')
    end

    it 'returns nil if graph does not exist' do
      cursor = double('Mongo::Cursor')
      allow(cursor).to receive(:first).and_return(nil)
      expect(mock_graphs_collection).to receive(:find).with({ 'id' => 'graph_1' }).and_return(cursor)

      result = storage_backend.fetch_graph_with_id('graph_1')
      expect(result).to be_nil
    end
  end

  describe '#delete_graph_with_id' do
    it 'deletes graph and associated commands' do
      expect(mock_graphs_collection).to receive(:delete_one).with({ 'id' => 'graph_1' })
      expect(mock_commands_collection).to receive(:delete_many).with({ 'graph_id' => 'graph_1' })

      storage_backend.delete_graph_with_id('graph_1')
    end
  end

  describe '#find_graphs_by_name' do
    it 'searches graphs by name pattern' do
      pattern = 'Test.*'
      expected_query = { 'name' => { '$regex' => pattern, '$options' => 'i' } }
      cursor = double('Mongo::Cursor')
      allow(cursor).to receive(:to_a).and_return([])

      expect(mock_graphs_collection).to receive(:find).with(expected_query).and_return(cursor)

      storage_backend.find_graphs_by_name(pattern)
    end
  end

  describe '#find_commands_by_class' do
    it 'searches commands by class name' do
      class_name = 'TestCommand'
      cursor = double('Mongo::Cursor')
      allow(cursor).to receive(:to_a).and_return([])

      expect(mock_commands_collection).to receive(:find).with({ 'class' => class_name }).and_return(cursor)

      storage_backend.find_commands_by_class(class_name)
    end
  end

  describe '#graph_statistics' do
    it 'returns aggregated statistics' do
      # Mock count operations
      expect(mock_graphs_collection).to receive(:count_documents).with({}).and_return(5)
      expect(mock_commands_collection).to receive(:count_documents).with({}).and_return(20)

      # Mock aggregation operations
      graphs_cursor = double('Mongo::Cursor')
      commands_cursor = double('Mongo::Cursor')
      allow(graphs_cursor).to receive(:to_a).and_return([{ '_id' => 'Graph1', 'count' => 3 }])
      allow(commands_cursor).to receive(:to_a).and_return([{ '_id' => 'TestCommand', 'count' => 15 }])

      expect(mock_graphs_collection).to receive(:aggregate).and_return(graphs_cursor)
      expect(mock_commands_collection).to receive(:aggregate).and_return(commands_cursor)

      stats = storage_backend.graph_statistics
      expect(stats[:total_graphs]).to eq(5)
      expect(stats[:total_commands]).to eq(20)
      expect(stats[:graphs_by_name]).to eq([{ '_id' => 'Graph1', 'count' => 3 }])
      expect(stats[:commands_by_class]).to eq([{ '_id' => 'TestCommand', 'count' => 15 }])
    end
  end

  describe '#schema_version' do
    context 'when config document exists' do
      it 'returns the stored schema version' do
        config_doc = { 'key' => described_class::SCHEMA_VERSION_KEY, 'value' => 1 }
        cursor = double('Mongo::Cursor')
        allow(cursor).to receive(:first).and_return(config_doc)
        expect(mock_config_collection).to receive(:find).with({ 'key' => described_class::SCHEMA_VERSION_KEY }).and_return(cursor)

        version = storage_backend.send(:schema_version)
        expect(version).to eq(1)
      end
    end

    context 'when config document does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        # Create fresh mocks for this test
        fresh_client = double('Mongo::Client')
        fresh_database = double('Mongo::Database')
        fresh_config_collection = double('Mongo::Collection')
        fresh_cursor = double('Mongo::Cursor')
        
        allow(Mongo::Client).to receive(:new).and_return(fresh_client)
        allow(fresh_client).to receive(:use).and_return(fresh_database)
        allow(fresh_database).to receive(:[]).and_return(fresh_config_collection)
        allow(fresh_config_collection).to receive(:indexes).and_return(mock_indexes)
        allow(fresh_config_collection).to receive(:replace_one)
        allow(fresh_cursor).to receive(:first).and_return({ 'key' => described_class::SCHEMA_VERSION_KEY, 'value' => 1 })
        allow(fresh_config_collection).to receive(:find).and_return(fresh_cursor)
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_string, database_name, global_config)
        
        # Now set up test-specific expectations
        test_cursor = double('Mongo::Cursor')
        allow(test_cursor).to receive(:first).and_return(nil)
        expect(fresh_config_collection).to receive(:find).with({ 'key' => described_class::SCHEMA_VERSION_KEY }).and_return(test_cursor)

        version = fresh_backend.send(:schema_version)
        expect(version).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end

    context 'when collection does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        # Create fresh mocks for this test
        fresh_client = double('Mongo::Client')
        fresh_database = double('Mongo::Database')
        fresh_config_collection = double('Mongo::Collection')
        fresh_cursor = double('Mongo::Cursor')
        
        allow(Mongo::Client).to receive(:new).and_return(fresh_client)
        allow(fresh_client).to receive(:use).and_return(fresh_database)
        allow(fresh_database).to receive(:[]).and_return(fresh_config_collection)
        allow(fresh_config_collection).to receive(:indexes).and_return(mock_indexes)
        allow(fresh_config_collection).to receive(:replace_one)
        allow(fresh_cursor).to receive(:first).and_return({ 'key' => described_class::SCHEMA_VERSION_KEY, 'value' => 1 })
        allow(fresh_config_collection).to receive(:find).and_return(fresh_cursor)
        
        # Create fresh backend
        fresh_backend = described_class.new(connection_string, database_name, global_config)
        
        # Now set up test-specific expectations
        expect(fresh_config_collection).to receive(:find).and_raise(StandardError)

        version = fresh_backend.send(:schema_version)
        expect(version).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end
  end

  describe '#update_schema_version' do
    it 'updates the schema version document' do
      expect(mock_config_collection).to receive(:replace_one).with(
        { 'key' => described_class::SCHEMA_VERSION_KEY },
        hash_including(
          'key' => described_class::SCHEMA_VERSION_KEY,
          'value' => 2
        ),
        { upsert: true }
      )

      storage_backend.send(:update_schema_version, 2)
    end
  end

  describe '#list_all_graph_ids' do
    context 'with no graphs' do
      it 'returns empty array' do
        expect(mock_graphs_collection).to receive(:find).with({}, projection: { 'id' => 1 }).and_return([])
        
        graph_ids = storage_backend.list_all_graph_ids
        expect(graph_ids).to eq([])
      end
    end

    context 'with stored graphs' do
      it 'returns all graph IDs' do
        mock_docs = [
          { 'id' => 'graph_1' },
          { 'id' => 'graph_2' },
          { 'id' => 'graph_3' }
        ]
        
        expect(mock_graphs_collection).to receive(:find).with({}, projection: { 'id' => 1 }).and_return(mock_docs)
        
        graph_ids = storage_backend.list_all_graph_ids
        expect(graph_ids).to contain_exactly('graph_1', 'graph_2', 'graph_3')
      end
    end
  end
  end
else
  puts "Skipping MongoStorageBackend tests - dependencies not available"
end
