require 'spec_helper'

# Test conditional class for testing
class TestConditional < CGE::Conditional
  def execute(options, next_command)
    # Simple test logic - if values match, continue to next command
    return next_command if options['value1'] == options['value2']
    nil
  end
  
  def determine_next_node(next_command)
    # This method is not used in the new architecture but kept for compatibility
    next_command
  end
end

# Test action class for testing
class TestCommandAction < CGE::Action
  def invoke
    # no-op
  end
end

describe CGE::CommandGraph do
  describe 'conditional command execution' do
    let(:action_command) { TestCommandAction.new('test_action', {}) }
    let(:conditional_command) { TestConditional.new('test_conditional', { 'value1' => 'test', 'value2' => 'test' }, action_command) }

    before do
      allow(TestConditional).to receive(:outputs).and_return({})
      allow(TestCommandAction).to receive(:outputs).and_return({})
    end

    it 'should continue execution when conditional returns next command' do
      command_graph = CGE::CommandGraph.new('test',conditional_command)
      
      # Test that the conditional passes through to next command when condition is true
      result = conditional_command.execute({ 'value1' => 'match', 'value2' => 'match' }, action_command)
      expect(result).to eq(action_command)
    end

    it 'should halt execution when conditional returns nil' do
      command_graph = CGE::CommandGraph.new('test',conditional_command)
      
      # Test that the conditional returns nil when condition is false
      result = conditional_command.execute({ 'value1' => 'no_match', 'value2' => 'different' }, action_command)
      expect(result).to be_nil
    end

    it 'should apply output substitutions to conditional options' do
      substitution_conditional = TestConditional.new('test_conditional', { 'value1' => '{{previous.output}}', 'value2' => 'expected' }, action_command)
      command_graph = CGE::CommandGraph.new('test',substitution_conditional)
      command_graph.instance_variable_get(:@variables)['previous.output'] = 'expected'
      
      substituted_options = command_graph.send(:substitute_variables, substitution_conditional.options, command_graph.instance_variable_get(:@variables))
      expect(substituted_options).to eq({ 'value1' => 'expected', 'value2' => 'expected' })
    end
  end
end