require 'spec_helper'

# Test action to verify functionality
class TestAction < DAF::Action
  attr_accessor :success
  alias invoke success
  attr_option :option, String
end

describe DAF::Action do
  let(:test_action) { TestAction.new('test_action', {}) }
  let(:options) { { 'option' => 'test' } }

  it 'should be configurable' do
    mixed_in = DAF::Action.ancestors.select { |o| o.instance_of?(Module) }
    expect(mixed_in).to include(DAF::Configurable)
  end

  it 'should have an execute method' do
    expect(test_action).to respond_to(:execute)
  end

  it 'should execute and return next command' do
    test_action.success = 123
    next_action = TestAction.new('next_action', {})
    result = test_action.execute(options, next_action)
    expect(result).to eq(next_action)
    expect(test_action.success).to eq(123)
  end

  it 'should set option values' do
    test_action.execute(options, nil)
    expect(test_action.option.value).to eq('test')
  end
end
