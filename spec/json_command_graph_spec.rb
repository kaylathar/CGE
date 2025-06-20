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
        expect { DAF::JSONCommandGraph.new(temp_file.path) }.to raise_error(DAF::CommandGraphException, 'Invalid Action, Monitor, or Input type')
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
    
    context 'Input -> Action chain' do
      let(:input_action_config) do
        {
          'Name' => 'Input-Action Chain',
          'Graph' => [
            {
              'Name' => 'myinput',
              'Type' => 'input',
              'Class' => 'DAF::ConstantInput',
              'Options' => {
                'constant' => 'Hello World'
              }
            },
            {
              'Name' => 'myaction',
              'Type' => 'action',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'from' => '+0987654321',
                'message' => 'Message: {{output}}',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(input_action_config.to_json)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:input)
        expect(current_node.underlying).to be_a(DAF::ConstantInput)
        
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should preserve template substitution for input outputs' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        sms_action_options = current_node.next.options
        expect(sms_action_options['message']).to eq('Message: {{output}}')
      end
    end
  end
  
  describe 'Constants functionality' do
    context 'with Constants defined in JSON' do
      let(:constants_config) do
        {
          'Name' => 'Constants Test Graph',
          'Constants' => {
            'admin_email' => 'admin@example.com',
            'base_path' => '/tmp/test',
            'api_key' => 'test_api_key_123',
            'phone_number' => '+1234567890'
          },
          'Graph' => [
            {
              'Name' => 'file_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '{{graph.base_path}}/monitored_file',
                'frequency' => 3
              }
            },
            {
              'Name' => 'email_action',
              'Type' => 'action',
              'Class' => 'DAF::EmailAction',
              'Options' => {
                'to' => '{{graph.admin_email}}',
                'from' => 'system@example.com',
                'subject' => 'File Update Alert',
                'body' => 'File updated at {{file_monitor.time}} in {{graph.base_path}}',
                'server' => 'smtp.example.com'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(constants_config.to_json)
        temp_file.close
      end
      
      it 'should parse constants from JSON configuration' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        outputs = graph.instance_variable_get(:@outputs)
        
        expect(outputs).to include('graph.admin_email' => 'admin@example.com')
        expect(outputs).to include('graph.base_path' => '/tmp/test')
        expect(outputs).to include('graph.api_key' => 'test_api_key_123')
        expect(outputs).to include('graph.phone_number' => '+1234567890')
      end
      
      it 'should preserve {{graph.constant_name}} patterns in node options' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        # Check monitor options contain the template patterns
        monitor_options = current_node.options
        expect(monitor_options['path']).to eq('{{graph.base_path}}/monitored_file')
        
        # Check action options contain the template patterns
        action_options = current_node.next.options
        expect(action_options['to']).to eq('{{graph.admin_email}}')
        expect(action_options['body']).to eq('File updated at {{file_monitor.time}} in {{graph.base_path}}')
      end
      
      it 'should correctly substitute constants when applying outputs' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        outputs = graph.instance_variable_get(:@outputs)
        
        # Test constant substitution in monitor options
        monitor_options = current_node.options
        substituted_monitor_options = graph.send(:apply_outputs, monitor_options, outputs)
        expect(substituted_monitor_options['path']).to eq('/tmp/test/monitored_file')
        
        # Test constant substitution in action options
        action_options = current_node.next.options
        substituted_action_options = graph.send(:apply_outputs, action_options, outputs)
        expect(substituted_action_options['to']).to eq('admin@example.com')
        expect(substituted_action_options['body']).to eq('File updated at {{file_monitor.time}} in /tmp/test')
      end
    end
    
    context 'with complex workflow using constants' do
      let(:complex_constants_config) do
        {
          'Name' => 'Complex Constants Workflow',
          'Constants' => {
            'notification_phone' => '+1987654321',
            'sms_sender' => '+1234567890',
            'twilio_sid' => 'test_sid_from_constants',
            'twilio_token' => 'test_token_from_constants',
            'watch_directory' => '/var/log/app',
            'backup_directory' => '/backup/logs'
          },
          'Graph' => [
            {
              'Name' => 'log_file_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '{{graph.watch_directory}}/application.log',
                'frequency' => 1
              }
            },
            {
              'Name' => 'backup_action',
              'Type' => 'action',
              'Class' => 'DAF::ShellAction',
              'Options' => {
                'command' => 'cp {{graph.watch_directory}}/application.log {{graph.backup_directory}}/app_{{log_file_monitor.time}}.log'
              }
            },
            {
              'Name' => 'notification_sms',
              'Type' => 'action',
              'Class' => 'DAF::SMSAction',
              'Options' => {
                'to' => '{{graph.notification_phone}}',
                'from' => '{{graph.sms_sender}}',
                'message' => 'Log file updated at {{log_file_monitor.time}}, backed up to {{graph.backup_directory}}',
                'sid' => '{{graph.twilio_sid}}',
                'token' => '{{graph.twilio_token}}'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(complex_constants_config.to_json)
        temp_file.close
      end
      
      it 'should create correct chain structure with constants' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::ShellAction)
        
        expect(current_node.next.next.type).to eq(:action)
        expect(current_node.next.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should substitute all constants correctly in complex workflow' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        outputs = graph.instance_variable_get(:@outputs)
        
        # Test monitor options substitution
        monitor_options = graph.send(:apply_outputs, current_node.options, outputs)
        expect(monitor_options['path']).to eq('/var/log/app/application.log')
        
        # Test first action (backup) options substitution
        backup_options = graph.send(:apply_outputs, current_node.next.options, outputs)
        expect(backup_options['command']).to eq('cp /var/log/app/application.log /backup/logs/app_{{log_file_monitor.time}}.log')
        
        # Test second action (SMS) options substitution
        sms_options = graph.send(:apply_outputs, current_node.next.next.options, outputs)
        expect(sms_options['to']).to eq('+1987654321')
        expect(sms_options['from']).to eq('+1234567890')
        expect(sms_options['message']).to eq('Log file updated at {{log_file_monitor.time}}, backed up to /backup/logs')
        expect(sms_options['sid']).to eq('test_sid_from_constants')
        expect(sms_options['token']).to eq('test_token_from_constants')
      end
    end
    
    context 'without Constants section' do
      let(:no_constants_config) do
        {
          'Name' => 'No Constants Graph',
          'Graph' => [
            {
              'Name' => 'simple_monitor',
              'Type' => 'monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/simple_file',
                'frequency' => 5
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(no_constants_config.to_json)
        temp_file.close
      end
      
      it 'should handle missing Constants section gracefully' do
        expect { DAF::JSONCommandGraph.new(temp_file.path) }.not_to raise_error
      end
      
      it 'should have empty graph constants when no Constants section exists' do
        graph = DAF::JSONCommandGraph.new(temp_file.path)
        outputs = graph.instance_variable_get(:@outputs)
        
        # Should not have any graph.* keys
        graph_constants = outputs.select { |key, _| key.start_with?('graph.') }
        expect(graph_constants).to be_empty
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
    
    it 'should handle input type nodes' do
      input_data = {
        'Name' => 'myinput',
        'Type' => 'input',
        'Class' => 'DAF::ConstantInput',
        'Options' => {
          'constant' => 'test value'
        }
      }
      
      node = DAF::JSONCommandGraph::JSONGraphNode.new(input_data, nil)
      
      expect(node.type).to eq(:input)
      expect(node.underlying).to be_a(DAF::ConstantInput)
    end
    
    it 'should raise exception for invalid class names' do
      invalid_data = {
        'Name' => 'invalid_node',
        'Type' => 'monitor',
        'Class' => 'NonExistent::Class',
        'Options' => {}
      }
      
      expect { DAF::JSONCommandGraph::JSONGraphNode.new(invalid_data, nil) }.to raise_error(DAF::CommandGraphException, 'Invalid Action, Monitor, or Input type')
    end
  end
end