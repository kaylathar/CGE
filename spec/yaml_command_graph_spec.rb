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
        expect { DAF::YAMLCommandGraph.new(temp_file.path) }.to raise_error(DAF::CommandGraphException, 'Invalid Action, Monitor, or Input type')
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
        temp_file.write(input_action_config.to_yaml)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:input)
        expect(current_node.underlying).to be_a(DAF::ConstantInput)
        
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should preserve template substitution for input outputs' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        sms_action_options = current_node.next.options
        expect(sms_action_options['message']).to eq('Message: {{output}}')
      end
    end
  end
  
  describe 'Constants functionality' do
    context 'with Constants defined in YAML' do
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
              'Type' => 'monitor',
              'Name' => 'file_monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '{{graph.base_path}}/monitored_file',
                'frequency' => 3
              }
            },
            {
              'Type' => 'action',
              'Name' => 'email_action',
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
        temp_file.write(constants_config.to_yaml)
        temp_file.close
      end
      
      it 'should parse constants from YAML configuration' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        outputs = graph.instance_variable_get(:@outputs)
        
        expect(outputs).to include('graph.admin_email' => 'admin@example.com')
        expect(outputs).to include('graph.base_path' => '/tmp/test')
        expect(outputs).to include('graph.api_key' => 'test_api_key_123')
        expect(outputs).to include('graph.phone_number' => '+1234567890')
      end
      
      it 'should preserve {{graph.constant_name}} patterns in node options' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
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
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
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
              'Type' => 'monitor',
              'Name' => 'log_file_monitor',
              'Class' => 'DAF::FileUpdateMonitor',
              'Options' => {
                'path' => '{{graph.watch_directory}}/application.log',
                'frequency' => 1
              }
            },
            {
              'Type' => 'action',
              'Name' => 'backup_action',
              'Class' => 'DAF::ShellAction',
              'Options' => {
                'command' => 'cp {{graph.watch_directory}}/application.log {{graph.backup_directory}}/app_{{log_file_monitor.time}}.log'
              }
            },
            {
              'Type' => 'action',
              'Name' => 'notification_sms',
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
        temp_file.write(complex_constants_config.to_yaml)
        temp_file.close
      end
      
      it 'should create correct chain structure with constants' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        current_node = graph.instance_variable_get(:@current_node)
        
        expect(current_node.type).to eq(:monitor)
        expect(current_node.underlying).to be_a(DAF::FileUpdateMonitor)
        
        expect(current_node.next.type).to eq(:action)
        expect(current_node.next.underlying).to be_a(DAF::ShellAction)
        
        expect(current_node.next.next.type).to eq(:action)
        expect(current_node.next.next.underlying).to be_a(DAF::SMSAction)
      end
      
      it 'should substitute all constants correctly in complex workflow' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
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
              'Type' => 'monitor',
              'Name' => 'simple_monitor',
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
        temp_file.write(no_constants_config.to_yaml)
        temp_file.close
      end
      
      it 'should handle missing Constants section gracefully' do
        expect { DAF::YAMLCommandGraph.new(temp_file.path) }.not_to raise_error
      end
      
      it 'should have empty graph constants when no Constants section exists' do
        graph = DAF::YAMLCommandGraph.new(temp_file.path)
        outputs = graph.instance_variable_get(:@outputs)
        
        # Should not have any graph.* keys
        graph_constants = outputs.select { |key, _| key.start_with?('graph.') }
        expect(graph_constants).to be_empty
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
    
    it 'should handle input type nodes' do
      input_data = {
        'Name' => 'myinput',
        'Type' => 'input',
        'Class' => 'DAF::ConstantInput',
        'Options' => {
          'constant' => 'test value'
        }
      }
      
      node = DAF::YAMLCommandGraph::YAMLGraphNode.new(input_data, nil)
      
      expect(node.type).to eq(:input)
      expect(node.underlying).to be_a(DAF::ConstantInput)
    end
    
    it 'should raise exception for invalid class names' do
      invalid_data = {
        'Name' => 'invalid_test_monitor',
        'Type' => 'monitor',
        'Class' => 'NonExistent::Class',
        'Options' => {}
      }
      
      expect { DAF::YAMLCommandGraph::YAMLGraphNode.new(invalid_data, nil) }.to raise_error(DAF::CommandGraphException, 'Invalid Action, Monitor, or Input type')
    end
  end
end