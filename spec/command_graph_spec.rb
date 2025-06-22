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
  
  describe 'reset functionality' do
    let(:mock_initial_command) { double('InitialCommand') }
    let(:mock_next_command) { double('NextCommand') }
    let(:mock_initial_class) { double('InitialClass') }
    let(:mock_next_class) { double('NextClass') }
    let(:constants) { { 'base_path' => '/tmp', 'admin_email' => 'admin@test.com' } }
    let(:graph) { CGE::CommandGraph.new('test_graph', mock_initial_command, nil, constants) }
    
    before do
      allow(mock_initial_command).to receive(:class).and_return(mock_initial_class)
      allow(mock_next_command).to receive(:class).and_return(mock_next_class)
      allow(mock_initial_class).to receive(:outputs).and_return({'time' => String})
      allow(mock_next_class).to receive(:outputs).and_return({'result' => String})
      
      allow(mock_initial_command).to receive(:name).and_return('initial_command')
      allow(mock_initial_command).to receive(:inputs).and_return({})
      allow(mock_initial_command).to receive(:next).and_return(mock_next_command)
      allow(mock_initial_command).to receive(:execute).and_return(mock_next_command)
      allow(mock_initial_command).to receive(:time).and_return('2023-12-01')
      
      allow(mock_next_command).to receive(:name).and_return('next_command')
      allow(mock_next_command).to receive(:inputs).and_return({})
      allow(mock_next_command).to receive(:next).and_return(nil)
      allow(mock_next_command).to receive(:execute).and_return(nil)
      allow(mock_next_command).to receive(:result).and_return('completed')
    end
    
    it 'should reset current command to initial command' do
      # Simulate execution advancing to next command
      graph.instance_variable_set(:@current_command, mock_next_command)
      
      graph.reset
      
      expect(graph.instance_variable_get(:@current_command)).to eq(mock_initial_command)
    end
    
    it 'should preserve graph constants after reset' do
      # Add some command output variables
      variables = graph.instance_variable_get(:@variables)
      variables['initial_command.time'] = '2023-12-01'
      variables['next_command.result'] = 'completed'
      
      graph.reset
      
      reset_variables = graph.instance_variable_get(:@variables)
      expect(reset_variables['graph.base_path']).to eq('/tmp')
      expect(reset_variables['graph.admin_email']).to eq('admin@test.com')
    end
    
    it 'should clear variables after reset' do
      # Add some output variables
      variables = graph.instance_variable_get(:@variables)
      variables['initial_command.time'] = '2023-12-01'
      variables['next_command.result'] = 'completed'
      
      graph.reset
      
      reset_variables = graph.instance_variable_get(:@variables)
      expect(reset_variables).not_to have_key('initial_command.time')
      expect(reset_variables).not_to have_key('next_command.result')
    end
    
    it 'should preserve global configuration variables after reset' do
      mock_global_config = double('GlobalConfiguration')
      allow(mock_global_config).to receive(:outputs).and_return({'heartbeat' => Integer})
      allow(mock_global_config).to receive(:heartbeat).and_return(60)
      
      graph_with_global = CGE::CommandGraph.new('test', mock_initial_command, mock_global_config, constants)
      
      # Add command output variables
      variables = graph_with_global.instance_variable_get(:@variables)
      variables['initial_command.time'] = '2023-12-01'
      
      graph_with_global.reset
      
      reset_variables = graph_with_global.instance_variable_get(:@variables)
      expect(reset_variables['global.heartbeat']).to eq(60)
      expect(reset_variables).not_to have_key('initial_command.time')
    end
    
    it 'should cancel execution thread during reset' do
      mock_thread = double('Thread')
      expect(mock_thread).to receive(:kill)
      
      graph.instance_variable_set(:@thread, mock_thread)
      graph.reset
    end
    
    it 'should handle reset when no thread is running' do
      expect { graph.reset }.not_to raise_error
    end
  end
end