require 'spec_helper'

# Test conditional to verify functionality
class TestConditional < CGE::Conditional
  attr_input 'test_input', String, :required

  protected

  def determine_next_node(next_command)
    # Process the test option and return next command or nil based on value
    return next_command if @processed_inputs && @processed_inputs['test_input'] == 'success'
    nil
  end

  def process_inputs(inputs)
    @processed_inputs = inputs
    super(inputs)
  end
end

class EmptyConditional < CGE::Conditional
  # Does not implement condition_met? to test NotImplementedError
  # Need at least one input to initialize class variables
  attr_input 'dummy', String, :optional
end

describe CGE::Conditional do
  let(:empty_conditional) { EmptyConditional.new('empty', {}) }
  let(:test_conditional) { TestConditional.new('test', {}) }

  it 'should process inputs before evaluating condition' do
    next_node = double('next_node')
    conditional = TestConditional.new('test', {})
    expect(conditional.execute({ 'test_input' => 'success' }, next_node)).to eq(next_node)
  end
end