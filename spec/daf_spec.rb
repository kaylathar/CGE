require 'spec_helper'
include DAF

describe 'DAF' do
  context 'when start_dad is called' do
    let!(:data_source) do
      dup = class_double('DAF::YAMLDataSource').as_stubbed_const
      allow(dup).to receive(:new)
      dup
    end

    let!(:command) do
      dup = class_double('DAF::Command').as_stubbed_const
      allow(dup).to receive(:new).and_return('com')
      dup
    end

    let!(:dir) do
      dup = class_double('Dir').as_stubbed_const(
        transfer_nested_constants: true)
      allow(dup).to receive(:[]).and_return(%w(test1 test2))
      dup
    end

    let!(:dad) do
      dup = class_double('DAF::DynamicActionDaemon').as_stubbed_const
      allow(dup).to receive(:new).and_return(idad)
      dup
    end

    let(:idad) do
      dup = double('DAF::DynamicActionDaemon')
      allow(dup).to receive(:start)
      dup
    end

    it 'should print usage if argument is not directory' do
      expect(self).to receive(:print_usage)
      ARGV[0] = '/dev/null'
      start_dad
    end

    it 'should get list of files using Dir' do
      expect(dir).to receive(:[]).with('//*.yaml')
      ARGV[0] = '/'
      start_dad
    end

    it 'should generate a list of commands from each file' do
      expect(command).to receive(:new).twice
      expect(data_source).to receive(:new).with('test1')
      expect(data_source).to receive(:new).with('test2')
      ARGV[0] = '/'
      start_dad
    end

    it 'should create a new daemon with commands' do
      expect(dad).to receive(:new).with(%w(com com))
      ARGV[0] = '/'
      start_dad
    end

    it 'should start the daemon' do
      expect(idad).to receive(:start)
      ARGV[0] = '/'
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
    it 'should execute each command' do
      command1 = double('DAF::Command')
      command2 = double('DAF::Command')
      expect(command1).to receive(:execute)
      expect(command2).to receive(:execute)
      dad = DynamicActionDaemon.new([command1, command2])
      thread = Thread.new do
        dad.start
      end
      sleep(1)
      thread.kill
    end
  end
end
