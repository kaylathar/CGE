require 'spec_helper'

describe CGE::ComparisonConditional do
  let(:comparison_conditional) { CGE::ComparisonConditional.new('comparison_conditional', {}) }
  let(:dummy_next_node) { double('next_node') }
  
  # Helper method to check if condition passes (returns next_node vs nil)
  def evaluate_as_boolean(options)
    result = comparison_conditional.execute(options, dummy_next_node)
    # Returns next_node if condition is true, nil if false
    result == dummy_next_node
  end

  describe 'equality comparison (default)' do
    it 'should return true when values are equal' do
      options = { 'value1' => 'test', 'value2' => 'test' }
      expect(evaluate_as_boolean(options)).to be true
    end

    it 'should return false when values are not equal' do
      options = { 'value1' => 'test1', 'value2' => 'test2' }
      expect(evaluate_as_boolean(options)).to be false
    end
  end

  describe 'explicit equality operator' do
    it 'should work with eq operator' do
      options = { 'value1' => 'same', 'value2' => 'same', 'operator' => 'eq' }
      expect(evaluate_as_boolean(options)).to be true
    end
  end

  describe 'not equal operator' do
    it 'should return true when values are different' do
      options = { 'value1' => 'test1', 'value2' => 'test2', 'operator' => 'ne' }
      expect(evaluate_as_boolean(options)).to be true
    end

    it 'should return false when values are the same' do
      options = { 'value1' => 'same', 'value2' => 'same', 'operator' => 'ne' }
      expect(evaluate_as_boolean(options)).to be false
    end
  end

  describe 'numeric comparisons' do
    it 'should handle greater than comparison' do
      options = { 'value1' => '10', 'value2' => '5', 'operator' => 'gt' }
      expect(evaluate_as_boolean(options)).to be true
      
      options = { 'value1' => '3', 'value2' => '7', 'operator' => 'gt' }
      expect(evaluate_as_boolean(options)).to be false
    end

    it 'should handle less than comparison' do
      options = { 'value1' => '3', 'value2' => '7', 'operator' => 'lt' }
      expect(evaluate_as_boolean(options)).to be true
      
      options = { 'value1' => '10', 'value2' => '5', 'operator' => 'lt' }
      expect(evaluate_as_boolean(options)).to be false
    end

    it 'should handle greater than or equal comparison' do
      options = { 'value1' => '10', 'value2' => '10', 'operator' => 'gte' }
      expect(evaluate_as_boolean(options)).to be true
      
      options = { 'value1' => '15', 'value2' => '10', 'operator' => 'gte' }
      expect(evaluate_as_boolean(options)).to be true
      
      options = { 'value1' => '5', 'value2' => '10', 'operator' => 'gte' }
      expect(evaluate_as_boolean(options)).to be false
    end

    it 'should handle less than or equal comparison' do
      options = { 'value1' => '10', 'value2' => '10', 'operator' => 'lte' }
      expect(evaluate_as_boolean(options)).to be true
      
      options = { 'value1' => '5', 'value2' => '10', 'operator' => 'lte' }
      expect(evaluate_as_boolean(options)).to be true
      
      options = { 'value1' => '15', 'value2' => '10', 'operator' => 'lte' }
      expect(evaluate_as_boolean(options)).to be false
    end

    it 'should raise error for non-numeric values in numeric comparison' do
      options = { 'value1' => 'not_a_number', 'value2' => '10', 'operator' => 'gt' }
      expect { comparison_conditional.execute(options, dummy_next_node) }
        .to raise_error(ArgumentError)
    end
  end

  describe 'error handling' do
    it 'should raise error for unsupported operator' do
      options = { 'value1' => 'test', 'value2' => 'test', 'operator' => 'invalid_op' }
      expect { comparison_conditional.execute(options, dummy_next_node) }
        .to raise_error(CGE::OptionError, /Bad value for option operator/)
    end

    it 'should raise error when required values are missing' do
      expect { comparison_conditional.execute({}, dummy_next_node) }
        .to raise_error(CGE::OptionError, /Required option value1 missing/)
    end
  end
end