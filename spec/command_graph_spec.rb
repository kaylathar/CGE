require 'spec_helper'

describe CGE::CommandGraph do
  let(:mock_monitor) { double('Monitor') }
  let(:mock_action) { double('Action') }
  let(:mock_monitor_class) { double('MonitorClass') }
  let(:mock_action_class) { double('ActionClass') }
  let(:mock_global_config) { double('GlobalConfiguration') }
  
  before do
    allow(mock_monitor).to receive(:class).and_return(mock_monitor_class)
    allow(mock_action).to receive(:class).and_return(mock_action_class)
    allow(mock_monitor_class).to receive(:outputs).and_return({})
    allow(mock_action_class).to receive(:outputs).and_return({})
    allow(mock_global_config).to receive(:outputs).and_return({})
    
    # Mock the basic Command interface
    allow(mock_monitor).to receive(:name).and_return('test_monitor')
    allow(mock_monitor).to receive(:inputs).and_return({})
    allow(mock_monitor).to receive(:next).and_return(nil)
    allow(mock_monitor).to receive(:execute).and_return(nil)
    
    allow(mock_action).to receive(:name).and_return('test_action')
    allow(mock_action).to receive(:inputs).and_return({})
    allow(mock_action).to receive(:next).and_return(nil)
    allow(mock_action).to receive(:execute).and_return(nil)
  end
  
  
  describe 'template substitution' do
    let(:graph) { CGE::CommandGraph.new('test',mock_monitor) }
    
    context 'substitute_variables method' do
      it 'should apply template substitutions correctly in inputs' do
        outputs = { 'time' => '2023-12-01 10:30:00', 'data' => 'webhook_payload' }
        
        input_inputs = {
          'socket_path' => '/tmp/webhook_{{time}}',
          'message' => 'File modified at {{time}}, webhook received: {{data}}'
        }
        
        result = graph.send(:substitute_variables, input_inputs, outputs)
        
        expect(result['socket_path']).to eq('/tmp/webhook_2023-12-01 10:30:00')
        expect(result['message']).to eq('File modified at 2023-12-01 10:30:00, webhook received: webhook_payload')
      end
      
      it 'should handle multiple substitutions in a single input value' do
        outputs = { 'time' => '2023-12-01', 'contents' => 'file_data', 'data' => 'socket_data' }
        
        input_inputs = {
          'complex_message' => 'Time: {{time}}, File: {{contents}}, Socket: {{data}}'
        }
        
        result = graph.send(:substitute_variables, input_inputs, outputs)
        
        expect(result['complex_message']).to eq('Time: 2023-12-01, File: file_data, Socket: socket_data')
      end
      
      it 'should leave inputs unchanged when no template variables are present' do
        outputs = { 'time' => '2023-12-01', 'data' => 'test_data' }
        
        input_inputs = {
          'static_input' => 'no_templates_here',
          'another_input' => 'also_static'
        }
        
        result = graph.send(:substitute_variables, input_inputs, outputs)
        
        expect(result).to eq(input_inputs)
      end
      
      it 'should handle non-string input values without error' do
        outputs = { 'time' => '2023-12-01' }
        
        input_inputs = {
          'string_input' => 'has {{time}} template',
          'integer_input' => 42,
          'boolean_input' => true,
          'nil_input' => nil
        }
        
        result = graph.send(:substitute_variables, input_inputs, outputs)
        
        expect(result['string_input']).to eq('has 2023-12-01 template')
        expect(result['integer_input']).to eq(42)
        expect(result['boolean_input']).to eq(true)
        expect(result['nil_input']).to be_nil
      end
      
      it 'should convert output values to strings during substitution' do
        outputs = { 'count' => 42, 'active' => true, 'data' => nil }
        
        input_inputs = {
          'message' => 'Count: {{count}}, Active: {{active}}, Data: {{data}}'
        }
        
        result = graph.send(:substitute_variables, input_inputs, outputs)
        
        expect(result['message']).to eq('Count: 42, Active: true, Data: ')
      end
      
      it 'should create a clone of input inputs without modifying original' do
        outputs = { 'time' => '2023-12-01' }
        
        input_inputs = {
          'message' => 'Original {{time}} message'
        }
        original_inputs = input_inputs.dup
        
        result = graph.send(:substitute_variables, input_inputs, outputs)
        
        expect(input_inputs).to eq(original_inputs)
        expect(result['message']).to eq('Original 2023-12-01 message')
      end
    end
    
    context 'global configuration substitution' do
      let(:mock_heartbeat_option) { double('HeartbeatOption') }
      let(:mock_global_config_class) { double('GlobalConfigurationClass') }
      let(:graph_with_global_config) { CGE::CommandGraph.new('test',mock_monitor, mock_global_config) }
      
      before do
        allow(mock_global_config).to receive(:class).and_return(mock_global_config_class)
        allow(mock_global_config_class).to receive(:inputs).and_return({'heartbeat' => {}})
        allow(mock_global_config).to receive(:outputs).and_return({'heartbeat' => {}})
        allow(mock_heartbeat_option).to receive(:value).and_return(60)
        allow(mock_global_config).to receive(:heartbeat).and_return(60)
      end
      
      it 'should work without global configuration' do
        outputs = { 'time' => '2023-12-01' }
        
        input_inputs = {
          'message' => 'Time: {{time}}, Heartbeat: {{global.heartbeat}}'
        }
        
        result = graph.send(:substitute_variables, input_inputs, outputs)
        
        expect(result['message']).to eq('Time: 2023-12-01, Heartbeat: {{global.heartbeat}}')
      end
    end
  end
end