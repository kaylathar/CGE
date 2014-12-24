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
      'Monitor' => { 'Options' => {}, 'Type' => 'TestMonitor' },
      'Action' => { 'Options' => {
        'test' => '{{test}}',
        'test2' => 'thing: {{test2}}'
      }, 'Type' => 'TestAction' })
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

    it 'should throw an exception if class does not exist' do
      allow(yaml).to receive(:load_file).and_return(
        'Monitor' => { 'Options' => [], 'Type' => 'BadTestMonitor' },
        'Action' => { 'Options' => [], 'Type' => 'BadTestAction' })
      expect { DAF::YAMLDataSource.new('/tmp/new') }.to raise_error
    end
  end

  context 'when asked for action_options' do
    let(:itest_action) do
      double('TestAction')
    end
    let!(:test_action) do
      dup = class_double('TestAction').as_stubbed_const
      allow(dup).to receive(:new).and_return(itest_action)
      dup
    end
    let(:itest_monitor) do
      double('TestMonitor')
    end
    let!(:test_monitor) do
      dup = class_double('TestMonitor').as_stubbed_const
      allow(dup).to receive(:new).and_return(itest_monitor)
      dup
    end

    it 'should return raw options if no outputs defined' do
      allow(test_monitor).to receive(:outputs).and_return({})
      expect(data_source.action_options).to have_key('test')
      expect(data_source.action_options['test']).to eq('{{test}}')
      expect(data_source.action_options).to have_key('test2')
      expect(data_source.action_options['test2']).to eq('thing: {{test2}}')
    end

    it 'should return raw options if no outputs match outputs' do
      allow(test_monitor).to receive(:outputs).and_return(
        'another_test' => String
      )
      allow(itest_monitor).to receive(:another_test).and_return('test_output')
      expect(data_source.action_options).to have_key('test')
      expect(data_source.action_options['test']).to eq('{{test}}')
      expect(data_source.action_options).to have_key('test2')
      expect(data_source.action_options['test2']).to eq('thing: {{test2}}')
    end

    it 'should substitute outputs into options' do
      allow(test_monitor).to receive(:outputs).and_return(
        'test' => String
      )
      allow(itest_monitor).to receive(:test).and_return('test output')
      expect(data_source.action_options).to have_key('test')
      expect(data_source.action_options['test']).to eq('test output')
      expect(data_source.action_options).to have_key('test2')
      expect(data_source.action_options['test2']).to eq('thing: {{test2}}')
    end

    it 'should substitute multiple outputs into multiple inputs' do
      allow(test_monitor).to receive(:outputs).and_return(
        'test' => String,
        'test2' => String
      )
      allow(itest_monitor).to receive(:test).and_return('test output')
      allow(itest_monitor).to receive(:test2).and_return('aout')
      expect(data_source.action_options).to have_key('test')
      expect(data_source.action_options['test']).to eq('test output')
      expect(data_source.action_options).to have_key('test2')
      expect(data_source.action_options['test2']).to eq('thing: aout')
    end

  end
end
