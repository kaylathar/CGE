require 'spec_helper'

# Test conditional class for testing
class TestConditional < CGE::Conditional
  def execute(inputs, next_command, command_graph)
    # Simple test logic - if values match, continue to next command
    return next_command if inputs['value1'] == inputs['value2']
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
    let(:action_command) { TestCommandAction.new('test_action_id', 'test_action', {}, nil) }
    let(:conditional_command) { TestConditional.new('test_conditional_id', 'test_conditional', { 'value1' => 'test', 'value2' => 'test' }, action_command) }

    before do
      allow(TestConditional).to receive(:outputs).and_return({})
      allow(TestCommandAction).to receive(:outputs).and_return({})
      # Add id methods that are needed for node lookup
      allow(conditional_command).to receive(:id).and_return('test_conditional_id')
      allow(action_command).to receive(:id).and_return('test_action_id')
    end

    it 'should continue execution when conditional returns next command' do
      # Link the commands properly
      allow(conditional_command).to receive(:next_command).and_return(action_command)
      allow(action_command).to receive(:next_command).and_return(nil)
      subgraphs = { 'main' => conditional_command }
      command_graph = CGE::CommandGraph.new('test_conditional_graph_id', 'test', subgraphs, 'main')
      
      # Test that the conditional passes through to next command when condition is true
      result = conditional_command.execute({ 'value1' => 'match', 'value2' => 'match' }, action_command, command_graph)
      expect(result).to eq(action_command)
    end

    it 'should halt execution when conditional returns nil' do
      # Link the commands properly
      allow(conditional_command).to receive(:next_command).and_return(action_command)
      allow(action_command).to receive(:next_command).and_return(nil)
      subgraphs = { 'main' => conditional_command }
      command_graph = CGE::CommandGraph.new('test_conditional_halt_graph_id', 'test', subgraphs, 'main')
      
      # Test that the conditional returns nil when condition is false
      result = conditional_command.execute({ 'value1' => 'no_match', 'value2' => 'different' }, action_command, command_graph)
      expect(result).to be_nil
    end

    it 'should apply output substitutions to conditional inputs' do
      substitution_conditional = TestConditional.new('test_substitution_conditional_id', 'test_conditional', { 'value1' => '{{previous.output}}', 'value2' => 'expected' }, action_command)
      # Add proper linking and id methods
      allow(substitution_conditional).to receive(:next_command).and_return(action_command)
      allow(substitution_conditional).to receive(:id).and_return('test_substitution_conditional_id')
      allow(action_command).to receive(:next_command).and_return(nil)
      subgraphs = { 'main' => substitution_conditional }
      command_graph = CGE::CommandGraph.new('test_substitution_graph_id', 'test', subgraphs, 'main')
      command_graph.instance_variable_get(:@variables)['previous.output'] = 'expected'
      
      substituted_inputs = command_graph.send(:substitute_variables, substitution_conditional.inputs, command_graph.instance_variable_get(:@variables))
      expect(substituted_inputs).to eq({ 'value1' => 'expected', 'value2' => 'expected' })
    end
  end
end