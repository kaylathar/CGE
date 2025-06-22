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
    allow(mock_monitor).to receive(:options).and_return({})
    allow(mock_monitor).to receive(:next).and_return(nil)
    allow(mock_monitor).to receive(:execute).and_return(nil)
    
    allow(mock_action).to receive(:name).and_return('test_action')
    allow(mock_action).to receive(:options).and_return({})
    allow(mock_action).to receive(:next).and_return(nil)
    allow(mock_action).to receive(:execute).and_return(nil)
  end
  
  describe 'initialization' do
    it 'should initialize with a command' do
      graph = CGE::CommandGraph.new(mock_monitor)
      expect(graph.instance_variable_get(:@current_command)).to eq(mock_monitor)
      expect(graph.instance_variable_get(:@outputs)).to eq({})
    end
    
    it 'should initialize with a command and global configuration' do
      graph = CGE::CommandGraph.new(mock_monitor, mock_global_config)
      expect(graph.instance_variable_get(:@current_command)).to eq(mock_monitor)
      expect(graph.instance_variable_get(:@outputs)).to eq({})
      expect(graph.instance_variable_get(:@global_configuration)).to eq(mock_global_config)
    end
  end
  
  describe 'template substitution' do
    let(:graph) { CGE::CommandGraph.new(mock_monitor) }
    
    context 'apply_outputs method' do
      it 'should apply template substitutions correctly in options' do
        outputs = { 'time' => '2023-12-01 10:30:00', 'data' => 'webhook_payload' }
        
        input_options = {
          'socket_path' => '/tmp/webhook_{{time}}',
          'message' => 'File modified at {{time}}, webhook received: {{data}}'
        }
        
        result = graph.send(:apply_outputs, input_options, outputs)
        
        expect(result['socket_path']).to eq('/tmp/webhook_2023-12-01 10:30:00')
        expect(result['message']).to eq('File modified at 2023-12-01 10:30:00, webhook received: webhook_payload')
      end
      
      it 'should handle multiple substitutions in a single option value' do
        outputs = { 'time' => '2023-12-01', 'contents' => 'file_data', 'data' => 'socket_data' }
        
        input_options = {
          'complex_message' => 'Time: {{time}}, File: {{contents}}, Socket: {{data}}'
        }
        
        result = graph.send(:apply_outputs, input_options, outputs)
        
        expect(result['complex_message']).to eq('Time: 2023-12-01, File: file_data, Socket: socket_data')
      end
      
      it 'should leave options unchanged when no template variables are present' do
        outputs = { 'time' => '2023-12-01', 'data' => 'test_data' }
        
        input_options = {
          'static_option' => 'no_templates_here',
          'another_option' => 'also_static'
        }
        
        result = graph.send(:apply_outputs, input_options, outputs)
        
        expect(result).to eq(input_options)
      end
      
      it 'should handle non-string option values without error' do
        outputs = { 'time' => '2023-12-01' }
        
        input_options = {
          'string_option' => 'has {{time}} template',
          'integer_option' => 42,
          'boolean_option' => true,
          'nil_option' => nil
        }
        
        result = graph.send(:apply_outputs, input_options, outputs)
        
        expect(result['string_option']).to eq('has 2023-12-01 template')
        expect(result['integer_option']).to eq(42)
        expect(result['boolean_option']).to eq(true)
        expect(result['nil_option']).to be_nil
      end
      
      it 'should convert output values to strings during substitution' do
        outputs = { 'count' => 42, 'active' => true, 'data' => nil }
        
        input_options = {
          'message' => 'Count: {{count}}, Active: {{active}}, Data: {{data}}'
        }
        
        result = graph.send(:apply_outputs, input_options, outputs)
        
        expect(result['message']).to eq('Count: 42, Active: true, Data: ')
      end
      
      it 'should create a clone of input options without modifying original' do
        outputs = { 'time' => '2023-12-01' }
        
        input_options = {
          'message' => 'Original {{time}} message'
        }
        original_options = input_options.dup
        
        result = graph.send(:apply_outputs, input_options, outputs)
        
        expect(input_options).to eq(original_options)
        expect(result['message']).to eq('Original 2023-12-01 message')
      end
    end
    
    context 'global configuration substitution' do
      let(:mock_heartbeat_option) { double('HeartbeatOption') }
      let(:mock_global_config_class) { double('GlobalConfigurationClass') }
      let(:graph_with_global_config) { CGE::CommandGraph.new(mock_monitor, mock_global_config) }
      
      before do
        allow(mock_global_config).to receive(:class).and_return(mock_global_config_class)
        allow(mock_global_config_class).to receive(:options).and_return({'heartbeat' => {}})
        allow(mock_global_config).to receive(:outputs).and_return({'heartbeat' => {}})
        allow(mock_heartbeat_option).to receive(:value).and_return(60)
        allow(mock_global_config).to receive(:heartbeat).and_return(60)
      end
      
      it 'should work without global configuration' do
        outputs = { 'time' => '2023-12-01' }
        
        input_options = {
          'message' => 'Time: {{time}}, Heartbeat: {{global.heartbeat}}'
        }
        
        result = graph.send(:apply_outputs, input_options, outputs)
        
        expect(result['message']).to eq('Time: 2023-12-01, Heartbeat: {{global.heartbeat}}')
      end
    end
  end
end