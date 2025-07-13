require 'spec_helper'

# Test monitor to verify functionality
class TestMonitor < CGE::Monitor
  attr_input :input, String
  attr_reader :output

  def block_until_triggered
    @output = 123
  end
end

describe CGE::Monitor do
  let(:test_monitor) { TestMonitor.new('test_monitor_id', 'test_monitor', {}, nil) }
  let(:inputs) {{'input' => 'test'}}

  it 'should be configurable' do
    mixed_in = CGE::Monitor.ancestors.select { |o| o.instance_of?(Module) }
    expect(mixed_in).to include(CGE::Configurable)
  end

  it 'should have an execute method' do
    expect(test_monitor).to respond_to(:execute)
  end

  it 'should execute without requiring a block' do
    mock_graph = double('CommandGraph')
    expect { test_monitor.execute(inputs, nil, mock_graph) }.not_to raise_error
  end

  it 'should call block_until_triggered' do
    mock_graph = double('CommandGraph')
    test_monitor.execute(inputs, nil, mock_graph)
    expect(test_monitor.output).to eq(123)
  end

  it 'should return next command' do
    next_monitor = TestMonitor.new('next_monitor_id', 'next_monitor', {}, nil)
    mock_graph = double('CommandGraph')
    result = test_monitor.execute(inputs, next_monitor, mock_graph)
    expect(result).to eq(next_monitor)
  end

  it 'should set input values' do
    mock_graph = double('CommandGraph')
    test_monitor.execute(inputs, nil, mock_graph)
    expect(test_monitor.input.value).to eq('test')
  end
end
