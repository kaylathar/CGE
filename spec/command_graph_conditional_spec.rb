require 'spec_helper'

describe DAF::CommandGraph do
  describe 'conditional node execution' do
    let(:mock_conditional) { double('conditional') }
    let(:mock_action) { double('action') }
    let(:conditional_node) do
      DAF::CommandGraphNode.new(
        underlying: mock_conditional,
        type: :conditional,
        name: 'test_conditional',
        options: { 'value1' => 'test', 'value2' => 'test' }
      )
    end
    let(:action_node) do
      DAF::CommandGraphNode.new(
        underlying: mock_action,
        type: :action,
        name: 'test_action',
        next_node: nil,
        options: {}
      )
    end

    before do
      allow(mock_action).to receive(:activate)
      allow(mock_action).to receive(:class).and_return(double('action_class', outputs: {}))
    end

    it 'should continue execution when conditional returns next node' do
      conditional_node.instance_variable_set(:@next, action_node)
      allow(mock_conditional).to receive(:evaluate).and_return(action_node)

      command_graph = DAF::CommandGraph.new(conditional_node)
      result = command_graph.send(:execute_conditional_node, conditional_node)

      expect(result).to eq(action_node)
      expect(mock_conditional).to have_received(:evaluate)
    end

    it 'should halt execution when conditional returns nil' do
      conditional_node.instance_variable_set(:@next, action_node)
      allow(mock_conditional).to receive(:evaluate).and_return(nil)

      command_graph = DAF::CommandGraph.new(conditional_node)
      result = command_graph.send(:execute_conditional_node, conditional_node)

      expect(result).to be_nil
      expect(mock_conditional).to have_received(:evaluate)
    end

    it 'should apply output substitutions to conditional options' do
      options_with_substitution = { 'value1' => '{{previous.output}}', 'value2' => 'expected' }
      conditional_node.instance_variable_set(:@options, options_with_substitution)
      conditional_node.instance_variable_set(:@next, action_node)
      
      command_graph = DAF::CommandGraph.new(conditional_node)
      command_graph.instance_variable_get(:@outputs)['previous.output'] = 'expected'
      
      allow(mock_conditional).to receive(:evaluate).with({ 'value1' => 'expected', 'value2' => 'expected' }, action_node).and_return(action_node)
      
      command_graph.send(:execute_conditional_node, conditional_node)
      expect(mock_conditional).to have_received(:evaluate).with({ 'value1' => 'expected', 'value2' => 'expected' }, action_node)
    end
  end
end