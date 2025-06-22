require 'spec_helper'

# Test action to verify functionality
class TestAction < CGE::Action
  attr_accessor :success
  alias invoke success
  attr_input :input, String
end

describe CGE::Action do
  let(:test_action) { TestAction.new('test_action', {}) }
  let(:inputs) { { 'input' => 'test' } }

  it 'should be configurable' do
    mixed_in = CGE::Action.ancestors.select { |o| o.instance_of?(Module) }
    expect(mixed_in).to include(CGE::Configurable)
  end

  it 'should have an execute method' do
    expect(test_action).to respond_to(:execute)
  end

  it 'should execute and return next command' do
    test_action.success = 123
    next_action = TestAction.new('next_action', {})
    result = test_action.execute(inputs, next_action)
    expect(result).to eq(next_action)
    expect(test_action.success).to eq(123)
  end

  it 'should set input values' do
    test_action.execute(inputs, nil)
    expect(test_action.input.value).to eq('test')
  end
end
