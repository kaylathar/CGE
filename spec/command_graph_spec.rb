require 'spec_helper'

describe DAF::CommandGraph do
  let(:mock_monitor) { double('Monitor') }
  let(:mock_action) { double('Action') }
  let(:mock_monitor_class) { double('MonitorClass') }
  let(:mock_action_class) { double('ActionClass') }
  
  before do
    allow(mock_monitor).to receive(:class).and_return(mock_monitor_class)
    allow(mock_action).to receive(:class).and_return(mock_action_class)
    allow(mock_monitor_class).to receive(:outputs).and_return({})
    allow(mock_action_class).to receive(:outputs).and_return({})
  end
  
  describe 'initialization' do
    it 'should initialize with a graph node' do
      node = DAF::CommandGraphNode.new(
        underlying: mock_monitor,
        type: :monitor,
        next_node: nil,
        options: {}
      )
      
      graph = DAF::CommandGraph.new(node)
      expect(graph.instance_variable_get(:@current_node)).to eq(node)
      expect(graph.instance_variable_get(:@outputs)).to eq({})
    end
  end
  
  describe 'template substitution' do
    let(:graph) do
      node = DAF::CommandGraphNode.new(
        underlying: mock_monitor,
        type: :monitor,
        next_node: nil,
        options: {}
      )
      DAF::CommandGraph.new(node)
    end
    
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
  end
  
  describe 'graph execution chains' do
    context 'Monitor -> Action chain' do
      let(:mock_file_monitor) { double('FileUpdateMonitor') }
      let(:mock_sms_action) { double('SMSAction') }
      let(:mock_file_monitor_class) { double('FileUpdateMonitorClass') }
      let(:mock_sms_action_class) { double('SMSActionClass') }
      
      let(:action_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_sms_action,
          type: :action,
          next_node: nil,
          options: {
            'to' => '+1234567890',
            'message' => 'File updated at {{time}}',
            'from' => '+0987654321',
            'sid' => 'test_sid',
            'token' => 'test_token'
          }
        )
      end
      
      let(:monitor_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_file_monitor,
          type: :monitor,
          next_node: action_node,
          options: {
            'path' => '/tmp/test_file',
            'frequency' => 5
          }
        )
      end
      
      let(:graph) { DAF::CommandGraph.new(monitor_node) }
      
      before do
        allow(mock_file_monitor).to receive(:class).and_return(mock_file_monitor_class)
        allow(mock_sms_action).to receive(:class).and_return(mock_sms_action_class)
        allow(mock_file_monitor_class).to receive(:outputs).and_return({'time' => Time, 'contents' => String})
        allow(mock_sms_action_class).to receive(:outputs).and_return({'message_id' => String})
        
        # Set up return values for monitor
        allow(mock_file_monitor).to receive(:time).and_return(Time.parse('2023-12-01 15:30:00'))
        allow(mock_file_monitor).to receive(:contents).and_return('file content')
        
        # Mock the monitor trigger behavior to call the block
        allow(mock_file_monitor).to receive(:on_trigger) do |options, &block|
          block.call if block_given?
        end
        
        # Mock the action activation
        allow(mock_sms_action).to receive(:activate)
      end
      
      it 'should execute monitor node and call on_trigger with correct options' do
        expect(mock_file_monitor).to receive(:on_trigger).with(
          hash_including('path' => '/tmp/test_file', 'frequency' => 5)
        )
        
        graph.send(:execute_monitor_node, monitor_node)
      end
      
      it 'should execute action node with substituted options' do
        # First set up some outputs from a previous monitor
        graph.instance_variable_set(:@outputs, {
          'time' => '2023-12-01 15:30:00',
          'contents' => 'file content'
        })
        
        # Set current node to action node
        graph.instance_variable_set(:@current_node, action_node)
        
        expected_options = {
          'to' => '+1234567890',
          'message' => 'File updated at 2023-12-01 15:30:00',
          'from' => '+0987654321',
          'sid' => 'test_sid',
          'token' => 'test_token'
        }
        
        expect(mock_sms_action).to receive(:activate).with(expected_options)
        
        graph.send(:execute_action_node, action_node)
      end
    end
    
    context 'Monitor -> Monitor -> Action chain' do
      let(:mock_file_monitor) { double('FileUpdateMonitor') }
      let(:mock_socket_monitor) { double('UnixSocketMonitor') }
      let(:mock_sms_action) { double('SMSAction') }
      
      let(:action_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_sms_action,
          type: :action,
          next_node: nil,
          options: {
            'to' => '+1234567890',
            'message' => 'File modified at {{time}}, webhook data: {{data}}',
            'from' => '+0987654321',
            'sid' => 'test_sid',
            'token' => 'test_token'
          }
        )
      end
      
      let(:socket_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_socket_monitor,
          type: :monitor,
          next_node: action_node,
          options: {
            'socket_path' => '/tmp/webhook_{{time}}.sock'
          }
        )
      end
      
      let(:file_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_file_monitor,
          type: :monitor,
          next_node: socket_node,
          options: {
            'path' => '/tmp/source_file',
            'frequency' => 2
          }
        )
      end
      
      let(:graph) { DAF::CommandGraph.new(file_node) }
      
      before do
        # Set up monitor classes and outputs
        file_monitor_class = double('FileUpdateMonitorClass')
        socket_monitor_class = double('UnixSocketMonitorClass')
        sms_action_class = double('SMSActionClass')
        
        allow(mock_file_monitor).to receive(:class).and_return(file_monitor_class)
        allow(mock_socket_monitor).to receive(:class).and_return(socket_monitor_class)
        allow(mock_sms_action).to receive(:class).and_return(sms_action_class)
        
        allow(file_monitor_class).to receive(:outputs).and_return({'time' => Time, 'contents' => String})
        allow(socket_monitor_class).to receive(:outputs).and_return({'data' => String})
        allow(sms_action_class).to receive(:outputs).and_return({'message_id' => String})
      end
      
      it 'should apply template substitution from first monitor to second monitor' do
        # Set up outputs from first monitor
        outputs = { 'time' => '2023-12-01_15:30:00', 'contents' => 'file data' }
        
        socket_options = socket_node.options
        substituted_options = graph.send(:apply_outputs, socket_options, outputs)
        
        expect(substituted_options['socket_path']).to eq('/tmp/webhook_2023-12-01_15:30:00.sock')
      end
      
      it 'should apply template substitution from both monitors to final action' do
        # Set up outputs from both monitors
        outputs = { 
          'time' => '2023-12-01 15:30:00',
          'contents' => 'file data',
          'data' => 'webhook payload'
        }
        
        action_options = action_node.options
        substituted_options = graph.send(:apply_outputs, action_options, outputs)
        
        expect(substituted_options['message']).to eq(
          'File modified at 2023-12-01 15:30:00, webhook data: webhook payload'
        )
        expect(substituted_options['to']).to eq('+1234567890')
        expect(substituted_options['from']).to eq('+0987654321')
      end
    end
    
    context 'Action -> Monitor -> Action chain' do
      let(:mock_shell_action) { double('ShellAction') }
      let(:mock_file_monitor) { double('FileUpdateMonitor') }
      let(:mock_email_action) { double('EmailAction') }
      
      let(:email_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_email_action,
          type: :action,
          next_node: nil,
          options: {
            'to' => 'admin@example.com',
            'subject' => 'Response received',
            'body' => 'File updated at {{time}} with content: {{contents}}',
            'from' => 'system@example.com',
            'server' => 'localhost'
          }
        )
      end
      
      let(:monitor_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_file_monitor,
          type: :monitor,
          next_node: email_node,
          options: {
            'path' => '/tmp/response_file',
            'frequency' => 2
          }
        )
      end
      
      let(:shell_node) do
        DAF::CommandGraphNode.new(
          underlying: mock_shell_action,
          type: :action,
          next_node: monitor_node,
          options: {
            'command' => 'echo "startup" > /tmp/startup_trigger'
          }
        )
      end
      
      let(:graph) { DAF::CommandGraph.new(shell_node) }
      
      before do
        shell_action_class = double('ShellActionClass')
        file_monitor_class = double('FileUpdateMonitorClass')
        email_action_class = double('EmailActionClass')
        
        allow(mock_shell_action).to receive(:class).and_return(shell_action_class)
        allow(mock_file_monitor).to receive(:class).and_return(file_monitor_class)
        allow(mock_email_action).to receive(:class).and_return(email_action_class)
        
        allow(shell_action_class).to receive(:outputs).and_return({'exit_code' => Integer})
        allow(file_monitor_class).to receive(:outputs).and_return({'time' => Time, 'contents' => String})
        allow(email_action_class).to receive(:outputs).and_return({'message_id' => String})
      end
      
      it 'should execute action first, then monitor, then final action with substituted values' do
        # Test that monitor options are not affected by shell action (no templates)
        monitor_options = monitor_node.options
        substituted_monitor_options = graph.send(:apply_outputs, monitor_options, {})
        
        expect(substituted_monitor_options).to eq(monitor_options)
        
        # Test that final action receives monitor outputs
        outputs = {
          'time' => '2023-12-01 16:45:00',
          'contents' => 'response data here'
        }
        
        email_options = email_node.options
        substituted_email_options = graph.send(:apply_outputs, email_options, outputs)
        
        expect(substituted_email_options['body']).to eq(
          'File updated at 2023-12-01 16:45:00 with content: response data here'
        )
        expect(substituted_email_options['to']).to eq('admin@example.com')
        expect(substituted_email_options['subject']).to eq('Response received')
      end
    end
  end
  
  describe 'CommandGraphNode' do
    it 'should create a node with all attributes' do
      node = DAF::CommandGraphNode.new(
        underlying: mock_monitor,
        type: :monitor,
        next_node: nil,
        options: { 'path' => '/tmp/test', 'frequency' => 5 }
      )
      
      expect(node.type).to eq(:monitor)
      expect(node.underlying).to eq(mock_monitor)
      expect(node.next).to be_nil
      expect(node.options).to eq({ 'path' => '/tmp/test', 'frequency' => 5 })
    end
    
    it 'should link nodes correctly' do
      second_node = DAF::CommandGraphNode.new(
        underlying: mock_action,
        type: :action,
        next_node: nil,
        options: {}
      )
      
      first_node = DAF::CommandGraphNode.new(
        underlying: mock_monitor,
        type: :monitor,
        next_node: second_node,
        options: {}
      )
      
      expect(first_node.next).to eq(second_node)
      expect(second_node.next).to be_nil
    end
  end
end