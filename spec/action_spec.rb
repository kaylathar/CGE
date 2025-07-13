require 'spec_helper'

# Test action to verify functionality
class TestAction < CGE::Action
  attr_accessor :success
  alias invoke success
  attr_input :input, String
end

describe CGE::Action do
  let(:test_action) { TestAction.new('test_action_id', 'test_action', {}, nil) }
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
    next_action = TestAction.new('next_action_id', 'next_action', {}, nil)
    mock_graph = double('CommandGraph')
    result = test_action.execute(inputs, next_action, mock_graph)
    expect(result).to eq(next_action)
    expect(test_action.success).to eq(123)
  end

  it 'should set input values' do
    mock_graph = double('CommandGraph')
    test_action.execute(inputs, nil, mock_graph)
    expect(test_action.input.value).to eq('test')
  end
  
  it 'should have a readable id property' do
    action = TestAction.new('custom_action_id', 'test', {}, nil)
    expect(action.id).to eq('custom_action_id')
  end
  
  it 'should auto-generate id when not provided' do
    action = TestAction.new(nil, 'test', {})
    expect(action.id).to be_a(String)
    expect(action.id.length).to eq(36) # UUID format
  end
end
