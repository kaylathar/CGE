require 'spec_helper'

# Test conditional to verify functionality
class TestConditional < DAF::Conditional
  attr_option 'test_option', String, :required

  protected

  def determine_next_node(next_node)
    test_option.value == 'success' ? next_node : nil
  end
end

class EmptyConditional < DAF::Conditional
  # Does not implement condition_met? to test NotImplementedError
  # Need at least one option to initialize class variables
  attr_option 'dummy', String, :optional
end

describe DAF::Conditional do
  let(:empty_conditional) { EmptyConditional.new }
  let(:test_conditional) { TestConditional.new }

  it 'should process options before evaluating condition' do
    next_node = double('next_node')
    expect(test_conditional.evaluate({ 'test_option' => 'success' }, next_node)).to eq(next_node)
    expect(test_conditional.evaluate({ 'test_option' => 'failure' }, next_node)).to be_nil
  end
end