require 'spec_helper'
require 'tempfile'
require 'yaml'

describe DAF::YAMLCommandGraph do
  let(:temp_file) { Tempfile.new(['test_config', '.yaml']) }
  
  after { temp_file.unlink }
  
  describe 'initialization' do
    context 'with valid YAML configuration' do
      let(:config_data) do
        {
          'Name' => 'Test Command Graph',
          'Graph' => [
            {
              'Type' => 'monitor',
              'Name' => 'file_monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/test_file',
                'frequency' => 5
              }
            },
            {
              'Type' => 'action',
              'Name' => 'sms_action', 
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'File updated at {{file_monitor.time}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(config_data.to_yaml)
        temp_file.close
      end
      
      it 'should load the YAML configuration correctly' do
        expect { DAF::YAMLCommandGraph.new(temp_file.path) }.not_to raise_error
      end
      
      it 'should set the name from YAML configuration' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        expect(graph.name).to eq('Test Command Graph')
      end
      
      it 'should create nodes with correct types' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should preserve options for each node' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.options).to include('path' => '/tmp/test_file', 'frequency' => 5)
        expect(current_node.next.options).to include('to' => '+1234567890', 'message' => 'File updated at {{file_monitor.time}}')
      end
    end
    
    context 'with invalid class name' do
      let(:invalid_config) do
        {
          'Name' => 'Invalid Graph',
          'Graph' => [
            {
              'Type' => 'monitor',
              'Name' => 'invalid_monitor',
              'Class' => 'DAF::NonExistentMonitor',
              'Options' => {}
            }
          ]
        }
      end
      
      before do
        temp_file.write(invalid_config.to_yaml)
        temp_file.close
      end
      
      it 'should raise CommandGraphException for invalid class' do
        expect { DAF::YAMLCommandGraph.new(temp_file.path) }.to raise_error(DAF::CommandGraphException, 'Invalid Action or Monitor type')
      end
    end
  end
  
  describe 'complex graph structures' do
    context 'Monitor -> Monitor -> Action chain' do
      let(:monitor_monitor_action_config) do
        {
          'Name' => 'Monitor-Monitor-Action Chain',
          'Graph' => [
            {
              'Type' => 'monitor',
              'Name' => 'source_file_monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/source_file',
                'frequency' => 2
              }
            },
            {
              'Type' => 'monitor',
              'Name' => 'webhook_socket_monitor',
              'Class' => 'DAF::UnixSocketMonitor', 
              'Options' => {
                'socket_path' => '/tmp/webhook_{{source_file_monitor.time}}'
              }
            },
            {
              'Type' => 'action',
              'Name' => 'notification_sms',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'File modified at {{source_file_monitor.time}}, webhook data: {{webhook_socket_monitor.data}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(monitor_monitor_action_config.to_yaml)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        
        expect(current_node.next.type).to eq(:monitor)
        expect(current_node.next.underlying).to be_a(DAF::UnixSocketMonitor)
        
        expect(current_node.next.next.type).to eq(:action)
        expect(current_node.next.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should preserve template substitution patterns' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        socket_monitor_options = current_node.next.options
        expect(socket_monitor_options['socket_path']).to eq('/tmp/webhook_{{source_file_monitor.time}}')
        
        sms_action_options = current_node.next.next.options
        expect(sms_action_options['message']).to eq('File modified at {{source_file_monitor.time}}, webhook data: {{webhook_socket_monitor.data}}')
      end
    end
    
    context 'Monitor -> Action -> Action chain' do
      let(:monitor_action_action_config) do
        {
          'Name' => 'Monitor-Action-Action Chain',
          'Graph' => [
            {
              'Type' => 'monitor',
              'Name' => 'watched_file_monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/watched_file',
                'frequency' => 3
              }
            },
            {
              'Type' => 'action',
              'Name' => 'email_alert',
              'Class' => 'DAF::EmailAction',
              'Options' => {
                'to' => 'admin@example.com',
                'from' => 'system@example.com',
                'subject' => 'File Alert',
                'body' => 'File changed at {{watched_file_monitor.time}}',
                'server' => 'smtp.example.com'
              }
            },
            {
              'Type' => 'action',
              'Name' => 'sms_alert',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'Email sent, file changed at {{watched_file_monitor.time}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(monitor_action_action_config.to_yaml)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::EmailAction)
        
        expect(current_node.next.next.type).to eq(:action)
        expect(current_node.next.next.underlying).to be_a(DAF::SMSAction)
      end
    end
    
    context 'Monitor -> Action -> Monitor chain' do
      let(:monitor_action_monitor_config) do
        {
          'Name' => 'Monitor-Action-Monitor Chain',
          'Graph' => [
            {
              'Type' => 'monitor',
              'Name' => 'trigger_file_monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/trigger_file',
                'frequency' => 1
              }
            },
            {
              'Type' => 'action',
              'Name' => 'shell_processor',
              'Class' => 'DAF::ShellAction',
              'Options' => {
                'command' => 'echo "{{trigger_file_monitor.time}}" > /tmp/processed_{{trigger_file_monitor.time}}'
              }
            },
            {
              'Type' => 'monitor',
              'Name' => 'final_socket_monitor',
              'Class' => 'DAF::UnixSocketMonitor',
              'Options' => {
                'socket_path' => '/tmp/final_socket'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(monitor_action_monitor_config.to_yaml)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::ShellAction)
        
        expect(current_node.next.next.type).to eq(:monitor)
        expect(current_node.next.next.underlying).to be_a(DAF::UnixSocketMonitor)
      end
    end
    
    context 'Action -> Monitor -> Action chain' do
      let(:action_monitor_action_config) do
        {
          'Name' => 'Action-Monitor-Action Chain',
          'Graph' => [
            {
              'Type' => 'action',
              'Name' => 'startup_trigger',
              'Class' => 'DAF::ShellAction',
              'Options' => {
                'command' => 'touch /tmp/startup_trigger'
              }
            },
            {
              'Type' => 'monitor',
              'Name' => 'response_file_monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/response_file',
                'frequency' => 2
              }
            },
            {
              'Type' => 'action',
              'Name' => 'response_sms',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'Response received at {{response_file_monitor.time}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(action_monitor_action_config.to_yaml)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:action)
        expect(current_node.underlying).to be_a(DAF::ShellAction)
        
        expect(current_node.next.type).to eq(:monitor)
        expect(current_node.next.underlying).to be_a(DAF::FileUpdateMonitor)
        
        expect(current_node.next.next.type).to eq(:action)
        expect(current_node.next.next.underlying).to be_a(DAF::SMSAction)
      end
    end
  end
  
  
  describe 'YAMLGraphNode' do
    let(:node_data) do
      {
        'Type' => 'monitor',
        'Name' => 'test_monitor',
        'Class' => 'DAF::FileUpdateMonitor',
        'Options' => {
          'path' => '/tmp/test',
          'frequency' => 5
        }
      }
    end
    
    it 'should create a node with correct type and underlying object' do
      node = DAF::YAMLCommandGraph::YAMLGraphNode.new(node_data, nil)
      
      expect(node.type).to eq(:monitor)
      expect(node.underlying).to be_a(DAF::FileUpdateMonitor)
      expect(node.options).to eq({ 'path' => '/tmp/test', 'frequency' => 5 })
    end
    
    it 'should handle action type nodes' do
      action_data = {
        'Type' => 'action',
        'Name' => 'test_sms_action',
        'Class' => 'DAF::SMSAction',
        'Options' => {
          'to' => '+1234567890',
          'message' => 'test',
          'from' => '+0987654321',
          'sid' => 'test_sid',
          'token' => 'test_token'
        }
      }
      
      node = DAF::YAMLCommandGraph::YAMLGraphNode.new(action_data, nil)
      
      expect(node.type).to eq(:action)
      expect(node.underlying).to be_a(DAF::SMSAction)
    end
    
    it 'should raise exception for invalid class names' do
      invalid_data = {
        'Type' => 'monitor',
        'Name' => 'invalid_test_monitor',
        'Class' => 'NonExistent::Class',
        'Options' => {}
      }
      
      expect { DAF::YAMLCommandGraph::YAMLGraphNode.new(invalid_data, nil) }.to raise_error(DAF::CommandGraphException, 'Invalid Action or Monitor type')
    end
  end
end