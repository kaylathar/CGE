require 'spec_helper'
include CGE

describe 'CGE' do
  context 'when start_cgd is called' do
    let(:mock_command_graph1) { double('CGE::YAMLCommandGraph') }
    let(:mock_command_graph2) { double('CGE::YAMLCommandGraph') }
    let(:mock_global_config) { double('CGE::GlobalConfiguration') }
    
    let!(:yaml_command_graph_class) do
      dup = class_double('CGE::YAMLCommandGraph').as_stubbed_const
      allow(dup).to receive(:from_file).with('/test/file1.yaml', mock_global_config, anything).and_return(mock_command_graph1)
      allow(dup).to receive(:from_file).with('/test/file2.yaml', mock_global_config, anything).and_return(mock_command_graph2)
      dup
    end

    let(:mock_command_graph3) { double('CGE::JSONCommandGraph') }

    let!(:json_command_graph_class) do
      dup = class_double('CGE::JSONCommandGraph').as_stubbed_const
      allow(dup).to receive(:from_file).with('/test/file1.json', mock_global_config, anything).and_return(mock_command_graph3)
      dup
    end

    let!(:dir_class) do
      dup = class_double('Dir').as_stubbed_const(
        transfer_nested_constants: true
      )
      allow(dup).to receive(:[]).with('/test/*.yaml').and_return(['/test/file1.yaml', '/test/file2.yaml'])
      allow(dup).to receive(:[]).with('/test/*.json').and_return(['/test/file1.json'])
      dup
    end

    let(:mock_daemon_instance) do
      dup = double('CGE::CommandGraphExecutor')
      allow(dup).to receive(:start)
      dup
    end

    let!(:daemon_class) do
      dup = class_double('CGE::CommandGraphExecutor').as_stubbed_const
      allow(dup).to receive(:new).with([mock_command_graph1, mock_command_graph2, mock_command_graph3], mock_global_config).and_return(mock_daemon_instance)
      dup
    end

    before do
      # Mock File.directory? to return true for our test directory
      allow(File).to receive(:directory?).with('/test').and_return(true)
      allow(File).to receive(:directory?).with('/dev/null').and_return(false)
      
      # Mock parse_global_config to return a mock global config
      allow_any_instance_of(Object).to receive(:parse_global_config).and_return(mock_global_config)
      allow(mock_global_config).to receive(:log_level).and_return(CGE::Logging::LOG_LEVEL_NONE)
    end

    it 'should print usage if argument is not directory' do
      expect(self).to receive(:print_usage)
      ARGV[0] = '/dev/null'
      start_cgd
    end

    it 'should generate CommandGraph objects from each file' do
      expect(yaml_command_graph_class).to receive(:from_file).with('/test/file1.yaml', mock_global_config, anything)
      expect(yaml_command_graph_class).to receive(:from_file).with('/test/file2.yaml', mock_global_config, anything)
      expect(json_command_graph_class).to receive(:from_file).with('/test/file1.json', mock_global_config, anything)
      ARGV[0] = '/test'
      start_cgd
    end

    it 'should create a new daemon with command graphs' do
      expect(daemon_class).to receive(:new).with([mock_command_graph1, mock_command_graph2, mock_command_graph3], mock_global_config)
      ARGV[0] = '/test'
      start_cgd
    end

    it 'should start the daemon' do
      expect(mock_daemon_instance).to receive(:start)
      ARGV[0] = '/test'
      start_cgd
    end
  end

  context 'when usage information is printed' do
    it 'should write to stdout' do
      expect($stdout).to receive(:write).at_least(1).times
      print_usage
    end
  end
end

describe 'CGE::CommandGraphExecutor' do
  let(:command_graph1) { double('CGE::YAMLCommandGraph') }
  let(:command_graph2) { double('CGE::YAMLCommandGraph') }
  let(:executor) { CommandGraphExecutor.new([command_graph1, command_graph2], nil) }
  
  context 'when started' do
    it 'should execute each command graph with executor reference' do
      expect(command_graph1).to receive(:execute).with(executor)
      expect(command_graph2).to receive(:execute).with(executor)
      
      thread = Thread.new do
        executor.start
      end
      sleep(1)
      thread.kill
    end
  end
  
  describe '#add_command_graph' do
    let(:new_command_graph) { double('CGE::CommandGraph') }
    
    context 'when executor is not started' do
      it 'should add command graph to the list' do
        expect(executor.instance_variable_get(:@command_graphs)).not_to include(new_command_graph)
        
        executor.add_command_graph(new_command_graph)
        
        expect(executor.instance_variable_get(:@command_graphs)).to include(new_command_graph)
      end
      
      it 'should not execute the command graph immediately' do
        expect(new_command_graph).not_to receive(:execute)
        
        executor.add_command_graph(new_command_graph)
      end
    end
    
    context 'when executor is started' do
      before do
        # Mock the initial command graphs to avoid execution
        allow(command_graph1).to receive(:execute)
        allow(command_graph2).to receive(:execute)
        
        # Start the executor in a separate thread
        @executor_thread = Thread.new { executor.start }
        sleep(0.1) # Give it a moment to start
      end
      
      after do
        @executor_thread.kill if @executor_thread
      end
      
      it 'should add command graph and execute it immediately' do
        expect(new_command_graph).to receive(:execute).with(executor)
        
        executor.add_command_graph(new_command_graph)
      end
      
      it 'should be thread-safe' do
        expect(new_command_graph).to receive(:execute).with(executor)
        
        # This should work even when called from another thread
        Thread.new do
          executor.add_command_graph(new_command_graph)
        end.join
      end
    end
  end
end
