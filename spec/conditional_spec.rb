require 'spec_helper'

# Test conditional to verify functionality
class TestConditional < DAF::Conditional
  attr_option 'test_option', String, :required

  protected

  def determine_next_node(next_command)
    # Process the test option and return next command or nil based on value
    return next_command if @processed_options && @processed_options['test_option'] == 'success'
    nil
  end

  def process_options(options)
    @processed_options = options
    super(options)
  end
end

class EmptyConditional < DAF::Conditional
  # Does not implement condition_met? to test NotImplementedError
  # Need at least one option to initialize class variables
  attr_option 'dummy', String, :optional
end

describe DAF::Conditional do
  let(:empty_conditional) { EmptyConditional.new('empty', {}) }
  let(:test_conditional) { TestConditional.new('test', {}) }

  it 'should process options before evaluating condition' do
    next_node = double('next_node')
    conditional = TestConditional.new('test', {})
    expect(conditional.execute({ 'test_option' => 'success' }, next_node)).to eq(next_node)
  end
end