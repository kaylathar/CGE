require 'spec_helper'
require 'google/cloud/storage'
require 'cge/storage_backends/gcs_storage_backend'
require 'cge/storage_backend'
require 'cge/command'

describe CGE::GCSStorageBackend do
  let(:bucket_name) { 'test-cge-bucket' }
  let(:credentials_path) { '/path/to/credentials.json' }
  let(:global_config) { instance_double('GlobalConfiguration') }
  let(:storage_backend) { described_class.new(bucket_name, credentials_path, global_config) }

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

  let(:mock_storage) { instance_double('Google::Cloud::Storage::Project') }
  let(:mock_bucket) { instance_double('Google::Cloud::Storage::Bucket') }
  let(:mock_file) { instance_double('Google::Cloud::Storage::File') }

  before do
    allow(Google::Cloud::Storage).to receive(:new).and_return(mock_storage)
    allow(mock_storage).to receive(:bucket).and_return(mock_bucket)
    allow(mock_bucket).to receive(:create_file)
    allow(mock_bucket).to receive(:file).and_return(mock_file)
    allow(mock_file).to receive(:download).and_return(double(string: '{}'))
    allow(mock_file).to receive(:delete)
  end

  describe '#initialize' do
    it 'raises error if bucket not found' do
      allow(mock_storage).to receive(:bucket).and_return(nil)
      expect do
        described_class.new(bucket_name, credentials_path, global_config)
      end.to raise_error("Bucket #{bucket_name} not found")
    end
  end

  describe '#upgrade_if_needed' do
    context 'when schema version is SCHEMA_VERSION_NONE' do
      it 'creates index files' do
        expect(storage_backend).to receive(:create_index_file).with('graphs', {})
        expect(storage_backend).to receive(:create_index_file).with('commands', {})
        expect(storage_backend).to receive(:create_index_file).with('config',
                                                                    { described_class::SCHEMA_VERSION_KEY => described_class::SCHEMA_VERSION_CURRENT })
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_NONE)
        allow(storage_backend).to receive(:update_schema_version)

        storage_backend.send(:upgrade_if_needed)
      end
    end

    context 'when schema version is current' do
      it 'does not create index files' do
        allow(storage_backend).to receive(:schema_version).and_return(described_class::SCHEMA_VERSION_CURRENT)
        expect(storage_backend).not_to receive(:create_index_file)

        storage_backend.send(:upgrade_if_needed)
      end
    end
  end

  describe '#create_or_update_graph' do
    before do
      allow(storage_backend).to receive(:load_index).with('commands').and_return({})
      allow(storage_backend).to receive(:load_index).with('graphs').and_return({})
      allow(storage_backend).to receive(:save_index)
    end

    it 'stores commands and graph data in GCS' do
      # Expect command file creation
      expect(mock_bucket).to receive(:create_file) do |io, path|
        expect(path).to eq('commands/cmd_1.json')
        command_data = JSON.parse(io.string)
        expect(command_data['id']).to eq('cmd_1')
        expect(command_data['name']).to eq('test_command')
        expect(command_data['class']).to eq('TestCommand')
      end

      # Expect graph file creation
      expect(mock_bucket).to receive(:create_file) do |io, path|
        expect(path).to eq('graphs/graph_1.json')
        graph_data = JSON.parse(io.string)
        expect(graph_data['id']).to eq('graph_1')
        expect(graph_data['name']).to eq('Test Graph')
        expect(graph_data['final_command_id']).to eq('cmd_1')
      end

      # Expect index updates
      expect(storage_backend).to receive(:save_index).with('commands', anything)
      expect(storage_backend).to receive(:save_index).with('graphs', anything)

      storage_backend.create_or_update_graph(mock_graph)
    end
  end

  describe '#fetch_graph_with_id' do
    it 'retrieves and builds command graph from GCS' do
      # Mock graph file with separate objects
      graph_file = double('GCS::File')
      graph_data = {
        'name' => 'Test Graph',
        'final_command_id' => 'cmd_1',
        'constants' => { 'const_key' => 'const_value' }
      }
      graph_file_data = double(string: graph_data.to_json)

      expect(mock_bucket).to receive(:file).with('graphs/graph_1.json').and_return(graph_file)
      expect(graph_file).to receive(:download).and_return(graph_file_data)

      # Mock command file with separate objects
      command_file = double('GCS::File')
      command_data = {
        'id' => 'cmd_1',
        'name' => 'test_command',
        'class' => 'TestCommand',
        'previous_command_id' => nil,
        'inputs' => { 'param' => 'value' }
      }
      command_file_data = double(string: command_data.to_json)

      expect(mock_bucket).to receive(:file).with('commands/cmd_1.json').and_return(command_file)
      expect(command_file).to receive(:download).and_return(command_file_data)

      allow(CGE::Command).to receive(:safe_const_get).and_call_original
      allow(CGE::Command).to receive(:safe_const_get).with('TestCommand').and_return(TestCommand)
      expect(CGE::CommandGraph).to receive(:new).with(
        'graph_1', 'Test Graph', anything, global_config, { 'const_key' => 'const_value' }
      )

      storage_backend.fetch_graph_with_id('graph_1')
    end

    it 'returns nil if graph file does not exist' do
      expect(mock_bucket).to receive(:file).with('graphs/graph_1.json').and_return(nil)

      result = storage_backend.fetch_graph_with_id('graph_1')
      expect(result).to be_nil
    end
  end

  describe '#delete_graph_with_id' do
    it 'deletes graph and associated command files' do
      # Mock indexes
      graphs_index = { 'graph_1' => { 'final_command_id' => 'cmd_1' } }
      commands_index = { 'cmd_1' => {} }

      allow(storage_backend).to receive(:load_index).with('graphs').and_return(graphs_index)
      allow(storage_backend).to receive(:load_index).with('commands').and_return(commands_index)

      # Mock command file with command data
      command_data = {
        'id' => 'cmd_1',
        'previous_command_id' => nil
      }
      command_file_data = double(string: command_data.to_json)

      expect(mock_bucket).to receive(:file).with('graphs/graph_1.json').and_return(mock_file)
      expect(mock_file).to receive(:delete)

      expect(mock_bucket).to receive(:file).with('commands/cmd_1.json').and_return(mock_file)
      expect(mock_file).to receive(:download).and_return(command_file_data)
      expect(mock_file).to receive(:delete)

      expect(storage_backend).to receive(:save_index).with('graphs', {})
      expect(storage_backend).to receive(:save_index).with('commands', {})

      storage_backend.delete_graph_with_id('graph_1')
    end
  end

  describe '#schema_version' do
    context 'when config exists' do
      it 'returns the stored schema version' do
        config_data = { described_class::SCHEMA_VERSION_KEY => 1 }
        expect(storage_backend).to receive(:load_index).with('config').and_return(config_data)

        version = storage_backend.send(:schema_version)
        expect(version).to eq(1)
      end
    end

    context 'when config does not exist' do
      it 'returns SCHEMA_VERSION_NONE' do
        expect(storage_backend).to receive(:load_index).with('config').and_raise(StandardError)

        version = storage_backend.send(:schema_version)
        expect(version).to eq(described_class::SCHEMA_VERSION_NONE)
      end
    end
  end

  describe '#update_schema_version' do
    it 'updates the schema version in config' do
      config_data = { described_class::SCHEMA_VERSION_KEY => 1 }
      expect(storage_backend).to receive(:load_index).with('config').and_return(config_data)
      expect(storage_backend).to receive(:save_index).with('config', { described_class::SCHEMA_VERSION_KEY => 2 })

      storage_backend.send(:update_schema_version, 2)
    end
  end

  describe '#load_index' do
    it 'loads index data from GCS file' do
      index_data = { 'key' => 'value' }
      file_data = double(string: index_data.to_json)
      test_file = double('GCS::File')

      expect(mock_bucket).to receive(:file).with('indexes/test.json').and_return(test_file)
      expect(test_file).to receive(:download).and_return(file_data)

      result = storage_backend.send(:load_index, 'test')
      expect(result).to eq(index_data)
    end

    it 'returns empty hash if index file does not exist' do
      expect(mock_bucket).to receive(:file).with('indexes/test.json').and_return(nil)

      result = storage_backend.send(:load_index, 'test')
      expect(result).to eq({})
    end
  end

  describe '#save_index' do
    it 'saves index data to GCS file' do
      # Create fresh mocks to avoid constructor interference
      fresh_storage = double('Google::Cloud::Storage::Project')
      fresh_bucket = double('Google::Cloud::Storage::Bucket')
      fresh_file = double('Google::Cloud::Storage::File')
      
      allow(Google::Cloud::Storage).to receive(:new).and_return(fresh_storage)
      allow(fresh_storage).to receive(:bucket).and_return(fresh_bucket)
      allow(fresh_bucket).to receive(:create_file) # For constructor calls
      allow(fresh_bucket).to receive(:file).and_return(fresh_file)
      allow(fresh_file).to receive(:download).and_return(double(string: '{"schema_version": 1}'))
      
      # Create fresh backend 
      fresh_backend = described_class.new(bucket_name, credentials_path, global_config)
      
      # Now set up test-specific expectations
      index_data = { 'key' => 'value' }
      test_file = double('GCS::File')

      # Expect deletion of existing file
      expect(fresh_bucket).to receive(:file).with('indexes/test.json').and_return(test_file)
      expect(test_file).to receive(:delete)

      # Expect creation of new file  
      expect(fresh_bucket).to receive(:create_file) do |io, path|
        expect(path).to eq('indexes/test.json')
        expect(JSON.parse(io.string)).to eq(index_data)
      end

      fresh_backend.send(:save_index, 'test', index_data)
    end
  end

  describe '#list_all_graph_ids' do
    context 'with no graphs' do
      it 'returns empty array' do
        # Create completely fresh mocks for this test
        fresh_storage = instance_double('Google::Cloud::Storage::Project')
        fresh_bucket = instance_double('Google::Cloud::Storage::Bucket')
        
        allow(Google::Cloud::Storage).to receive(:new).and_return(fresh_storage)
        allow(fresh_storage).to receive(:bucket).and_return(fresh_bucket)
        
        # Mock initialization calls
        allow(fresh_bucket).to receive(:file).with('indexes/config.json').and_return(nil)
        allow(fresh_bucket).to receive(:create_file).with(anything, 'indexes/graphs.json')
        allow(fresh_bucket).to receive(:create_file).with(anything, 'indexes/commands.json')
        allow(fresh_bucket).to receive(:create_file).with(anything, 'indexes/config.json')
        
        fresh_backend = described_class.new('test-bucket', nil, global_config)
        
        # Mock empty graphs index
        empty_index_file = instance_double('Google::Cloud::Storage::File')
        empty_index_content = instance_double('StringIO')
        allow(empty_index_content).to receive(:string).and_return('{}')
        allow(empty_index_file).to receive(:download).and_return(empty_index_content)
        allow(fresh_bucket).to receive(:file).with('indexes/graphs.json').and_return(empty_index_file)
        
        graph_ids = fresh_backend.list_all_graph_ids
        expect(graph_ids).to eq([])
      end
    end

    context 'with stored graphs' do
      it 'returns all graph IDs' do
        # Create completely fresh mocks for this test
        fresh_storage = instance_double('Google::Cloud::Storage::Project')
        fresh_bucket = instance_double('Google::Cloud::Storage::Bucket')
        
        allow(Google::Cloud::Storage).to receive(:new).and_return(fresh_storage)
        allow(fresh_storage).to receive(:bucket).and_return(fresh_bucket)
        
        # Mock initialization calls
        allow(fresh_bucket).to receive(:file).with('indexes/config.json').and_return(nil)
        allow(fresh_bucket).to receive(:create_file).with(anything, 'indexes/graphs.json')
        allow(fresh_bucket).to receive(:create_file).with(anything, 'indexes/commands.json')
        allow(fresh_bucket).to receive(:create_file).with(anything, 'indexes/config.json')
        
        fresh_backend = described_class.new('test-bucket', nil, global_config)
        
        # Mock graphs index with data
        graphs_index_data = {
          'graph_1' => { 'name' => 'Graph 1', 'final_command_id' => 'cmd_1' },
          'graph_2' => { 'name' => 'Graph 2', 'final_command_id' => 'cmd_2' },
          'graph_3' => { 'name' => 'Graph 3', 'final_command_id' => 'cmd_3' }
        }
        
        index_file = instance_double('Google::Cloud::Storage::File')
        index_content = instance_double('StringIO')
        allow(index_content).to receive(:string).and_return(graphs_index_data.to_json)
        allow(index_file).to receive(:download).and_return(index_content)
        allow(fresh_bucket).to receive(:file).with('indexes/graphs.json').and_return(index_file)
        
        graph_ids = fresh_backend.list_all_graph_ids
        expect(graph_ids).to contain_exactly('graph_1', 'graph_2', 'graph_3')
      end
    end
  end
end
