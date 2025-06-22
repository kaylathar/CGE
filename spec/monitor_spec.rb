require 'spec_helper'

# Test monitor to verify functionality
class TestMonitor < DAF::Monitor
  attr_option :option, String
  attr_reader :output

  def block_until_triggered
    @output = 123
  end
end

describe DAF::Monitor do
  let(:test_monitor) { TestMonitor.new('test_monitor', {}) }
  let(:options) {{'option' => 'test'}}

  it 'should be configurable' do
    mixed_in = DAF::Monitor.ancestors.select { |o| o.instance_of?(Module) }
    expect(mixed_in).to include(DAF::Configurable)
  end

  it 'should have an execute method' do
    expect(test_monitor).to respond_to(:execute)
  end

  it 'should execute without requiring a block' do
    expect { test_monitor.execute(options, nil) }.not_to raise_error
  end

  it 'should call block_until_triggered' do
    test_monitor.execute(options, nil)
    expect(test_monitor.output).to eq(123)
  end

  it 'should return next command' do
    next_monitor = TestMonitor.new('next_monitor', {})
    result = test_monitor.execute(options, next_monitor)
    expect(result).to eq(next_monitor)
  end

  it 'should set option values' do
    test_monitor.execute(options, nil)
    expect(test_monitor.option.value).to eq('test')
  end
end
