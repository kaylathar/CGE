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
  let(:test_monitor) { TestMonitor.new }
  let(:options) {{'option' => 'test'}}

  it 'should be configurable' do
    mixed_in = DAF::Monitor.ancestors.select { |o| o.instance_of?(Module) }
    expect(mixed_in).to include(DAF::Configurable)
  end

  it 'should have an on_trigger method' do
    expect(test_monitor).to respond_to(:on_trigger)
  end

  it 'should require a block to execute' do
    expect { test_monitor.on_trigger(options) }.to raise_error(LocalJumpError)
  end

  it 'should call block_until_triggered' do
    test_monitor.on_trigger(options) {}
    expect(test_monitor.output).to eq(123)
  end

  it 'should yield to a given block when triggered' do
    expect { |b| test_monitor.on_trigger(options,&b) }
      .to yield_with_no_args
  end

  it 'should set option values' do
    test_monitor.on_trigger(options) {}
    expect(test_monitor.option.value).to eq('test')
  end
end
