require 'spec_helper'
require 'tempfile'
require 'json'

describe DAF::JSONCommandGraph do
  let(:temp_file) { Tempfile.new(['test_config', '.json']) }
  
  after { temp_file.unlink }
  
  describe 'initialization' do
    context 'with valid JSON configuration' do
      let(:config_data) do
        {
          'Name' => 'Test Command Graph',
          'Graph' => [
            {
              'Name' => 'file_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/test_file',
                'frequency' => 5
              }
            },
            {
              'Name' => 'sms_alert',
              'Type' => 'action', 
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
        temp_file.write(config_data.to_json)
        temp_file.close
      end
      
      it 'should load the JSON configuration correctly' do
        expect { DAF::JSONCommandGraph.new(temp_file.path) }.not_to raise_error
      end
      
      it 'should set the name from JSON configuration' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        expect(graph.name).to eq('Test Command Graph')
      end
      
      it 'should create nodes with correct types' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should preserve options for each node' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
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
              'Name' => 'invalid_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::NonExistentMonitor',
              'Options' => {}
            }
          ]
        }
      end
      
      before do
        temp_file.write(invalid_config.to_json)
        temp_file.close
      end
      
      it 'should raise CommandGraphException for invalid class' do
        expect { DAF::JSONCommandGraph.new(temp_file.path) }.to raise_error(DAF::CommandGraphException, 'Invalid Action or Monitor type')
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
              'Name' => 'file_watcher',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/source_file',
                'frequency' => 2
              }
            },
            {
              'Name' => 'socket_listener',
              'Type' => 'monitor',
              'Class' => 'DAF::UnixSocketMonitor', 
              'Options' => {
                'socket_path' => '/tmp/webhook_{{file_watcher.time}}'
              }
            },
            {
              'Name' => 'notification_sender',
              'Type' => 'action',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'File modified at {{file_watcher.time}}, webhook data: {{socket_listener.data}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(monitor_monitor_action_config.to_json)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        
        expect(current_node.next.type).to eq(:monitor)
        expect(current_node.next.underlying).to be_a(DAF::UnixSocketMonitor)
        
        expect(current_node.next.next.type).to eq(:action)
        expect(current_node.next.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should preserve template substitution patterns' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        socket_monitor_options = current_node.next.options
        expect(socket_monitor_options['socket_path']).to eq('/tmp/webhook_{{file_watcher.time}}')
        
        sms_action_options = current_node.next.next.options
        expect(sms_action_options['message']).to eq('File modified at {{file_watcher.time}}, webhook data: {{socket_listener.data}}')
      end
    end
    
    context 'Monitor -> Action -> Action chain' do
      let(:monitor_action_action_config) do
        {
          'Name' => 'Monitor-Action-Action Chain',
          'Graph' => [
            {
              'Name' => 'file_observer',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/watched_file',
                'frequency' => 3
              }
            },
            {
              'Name' => 'email_notifier',
              'Type' => 'action',
              'Class' => 'DAF::EmailAction',
              'Options' => {
                'to' => 'admin@example.com',
                'from' => 'system@example.com',
                'subject' => 'File Alert',
                'body' => 'File changed at {{file_observer.time}}',
                'server' => 'smtp.example.com'
              }
            },
            {
              'Name' => 'sms_backup',
              'Type' => 'action',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'Email sent, file changed at {{file_observer.time}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(monitor_action_action_config.to_json)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
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
              'Name' => 'trigger_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/trigger_file',
                'frequency' => 1
              }
            },
            {
              'Name' => 'processor',
              'Type' => 'action',
              'Class' => 'DAF::ShellAction',
              'Options' => {
                'command' => 'echo "{{trigger_monitor.time}}" > /tmp/processed_{{trigger_monitor.time}}'
              }
            },
            {
              'Name' => 'final_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::UnixSocketMonitor',
              'Options' => {
                'socket_path' => '/tmp/final_socket'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(monitor_action_monitor_config.to_json)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
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
              'Name' => 'startup_action',
              'Type' => 'action',
              'Class' => 'DAF::ShellAction',
              'Options' => {
                'command' => 'touch /tmp/startup_trigger'
              }
            },
            {
              'Name' => 'response_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/response_file',
                'frequency' => 2
              }
            },
            {
              'Name' => 'final_notification',
              'Type' => 'action',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'Response received at {{response_monitor.time}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(action_monitor_action_config.to_json)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
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
  
  
  describe 'JSONGraphNode' do
    let(:node_data) do
      {
        'Name' => 'test_monitor',
        'Type' => 'monitor',
        'Class' => 'DAF::FileUpdateMonitor',
        'Options' => {
          'path' => '/tmp/test',
          'frequency' => 5
        }
      }
    end
    
    it 'should create a node with correct type and underlying object' do
      node = DAF::JSONCommandGraph::JSONGraphNode.new(node_data, nil)
      
      expect(node.type).to eq(:monitor)
      expect(node.underlying).to be_a(DAF::FileUpdateMonitor)
      expect(node.options).to eq({ 'path' => '/tmp/test', 'frequency' => 5 })
    end
    
    it 'should handle action type nodes' do
      action_data = {
        'Name' => 'test_action',
        'Type' => 'action',
        'Class' => 'DAF::SMSAction',
        'Options' => {
          'to' => '+1234567890',
          'message' => 'test',
          'from' => '+0987654321',
          'sid' => 'test_sid',
          'token' => 'test_token'
        }
      }
      
      node = DAF::JSONCommandGraph::JSONGraphNode.new(action_data, nil)
      
      expect(node.type).to eq(:action)
      expect(node.underlying).to be_a(DAF::SMSAction)
    end
    
    it 'should raise exception for invalid class names' do
      invalid_data = {
        'Name' => 'invalid_node',
        'Type' => 'monitor',
        'Class' => 'NonExistent::Class',
        'Options' => {}
      }
      
      expect { DAF::JSONCommandGraph::JSONGraphNode.new(invalid_data, nil) }.to raise_error(DAF::CommandGraphException, 'Invalid Action or Monitor type')
    end
  end
end