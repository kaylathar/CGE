require 'spec_helper'
include DAF

describe 'DAF' do
  context 'when start_dad is called' do
    let(:mock_command_graph1) { double('DAF::YAMLCommandGraph') }
    let(:mock_command_graph2) { double('DAF::YAMLCommandGraph') }
    
    let!(:yaml_command_graph_class) do
      dup = class_double('DAF::YAMLCommandGraph').as_stubbed_const
      allow(dup).to receive(:new).with('/test/file1.yaml').and_return(mock_command_graph1)
      allow(dup).to receive(:new).with('/test/file2.yaml').and_return(mock_command_graph2)
      dup
    end

    let(:mock_command_graph3) { double('DAF::JSONCommandGraph') }

    let!(:json_command_graph_class) do
      dup = class_double('DAF::JSONCommandGraph').as_stubbed_const
      allow(dup).to receive(:new).with('/test/file1.json').and_return(mock_command_graph3)
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
      dup = double('DAF::DynamicActionDaemon')
      allow(dup).to receive(:start)
      dup
    end

    let!(:daemon_class) do
      dup = class_double('DAF::DynamicActionDaemon').as_stubbed_const
      allow(dup).to receive(:new).and_return(mock_daemon_instance)
      dup
    end

    before do
      # Mock File.directory? to return true for our test directory
      allow(File).to receive(:directory?).with('/test').and_return(true)
      allow(File).to receive(:directory?).with('/dev/null').and_return(false)
    end

    it 'should print usage if argument is not directory' do
      expect(self).to receive(:print_usage)
      ARGV[0] = '/dev/null'
      start_dad
    end

    it 'should get list of files using Dir' do
      expect(dir_class).to receive(:[]).with('/test/*.yaml')
      expect(dir_class).to receive(:[]).with('/test/*.json')
      ARGV[0] = '/test'
      start_dad
    end

    it 'should generate YAMLCommandGraph objects from each file' do
      expect(yaml_command_graph_class).to receive(:new).with('/test/file1.yaml')
      expect(yaml_command_graph_class).to receive(:new).with('/test/file2.yaml')
      expect(json_command_graph_class).to receive(:new).with('/test/file1.json')
      ARGV[0] = '/test'
      start_dad
    end

    it 'should create a new daemon with command graphs' do
      expect(daemon_class).to receive(:new).with([mock_command_graph1, mock_command_graph2, mock_command_graph3])
      ARGV[0] = '/test'
      start_dad
    end

    it 'should start the daemon' do
      expect(mock_daemon_instance).to receive(:start)
      ARGV[0] = '/test'
      start_dad
    end
  end

  context 'when usage information is printed' do
    it 'should write to stdout' do
      expect($stdout).to receive(:write).at_least(1).times
      print_usage
    end
  end
end

describe 'DAF::DynamicActionDaemon' do
  context 'when started' do
    it 'should execute each command graph' do
      command_graph1 = double('DAF::YAMLCommandGraph')
      command_graph2 = double('DAF::YAMLCommandGraph')
      expect(command_graph1).to receive(:execute)
      expect(command_graph2).to receive(:execute)
      dad = DynamicActionDaemon.new([command_graph1, command_graph2])
      thread = Thread.new do
        dad.start
      end
      sleep(1)
      thread.kill
    end
  end
end
