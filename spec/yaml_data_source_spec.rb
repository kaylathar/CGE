require 'spec_helper'

class TestMonitor < DAF::Monitor
end

class TestAction < DAF::Action
end

describe DAF::YAMLDataSource do
  let!(:yaml) do
    yaml = class_double('YAML').as_stubbed_const(
      transfer_nested_constants: true)
    allow(yaml).to receive(:load_file).and_return(
      'Monitor' => { 'Options' => [], 'Type' => 'TestMonitor' },
      'Action' => { 'Options' => [], 'Type' => 'TestAction' }
        )
    yaml
  end
  let(:data_source) { DAF::YAMLDataSource.new('/tmp/test') }

  context 'properties' do
    it 'responds to #monitor' do
      expect(data_source).to respond_to(:monitor)
    end

    it 'responds to #action' do
      expect(data_source).to respond_to(:action)
    end
  end

  context 'when new is called' do
    it 'should load the file at the given path' do
      expect(yaml).to receive(:load_file).with('/tmp/2')
      DAF::YAMLDataSource.new('/tmp/2')
    end

    it 'should initialize monitor class specified' do
      expect(data_source.monitor.class).to eq(TestMonitor)
    end

    it 'should initialize action class specified' do
      expect(data_source.action.class).to eq(TestAction)
    end
  end
end
