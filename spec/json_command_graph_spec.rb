require 'spec_helper'
require 'tempfile'
require 'json'

describe CGE::JSONCommandGraph do
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
              'Class' => 'CGE::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/test_file',
                'frequency' => 5
              }
            },
            {
              'Name' => 'sms_alert',
              'Class' => 'CGE::SMSAction',
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
        expect { CGE::JSONCommandGraph.from_file(temp_file.path) }.not_to raise_error
      end
      
      it 'should set the name from JSON configuration' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        expect(graph.name).to eq('Test Command Graph')
      end
      
      it 'should create commands with correct types' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        current_command = graph.instance_variable_get(:@current_command)
        
        expect(current_command).to be_a(CGE::FileUpdateMonitor)
        expect(current_command.name).to eq('file_monitor')
        expect(current_command.next_command).to be_a(CGE::SMSAction)
        expect(current_command.next_command.name).to eq('sms_alert')
      end
      
      it 'should preserve options for each command' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        current_command = graph.instance_variable_get(:@current_command)
        
        expect(current_command.options).to include('path' => '/tmp/test_file', 'frequency' => 5)
        expect(current_command.next_command.options).to include('to' => '+1234567890', 'message' => 'File updated at {{file_monitor.time}}')
      end
    end
    
    context 'with invalid class name' do
      let(:invalid_config) do
        {
          'Name' => 'Invalid Graph',
          'Graph' => [
            {
              'Name' => 'invalid_monitor',
              'Class' => 'CGE::NonExistentMonitor',
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
        expect { CGE::JSONCommandGraph.from_file(temp_file.path) }.to raise_error(CGE::CommandGraphException, 'Invalid Action, Monitor, or Input type')
      end
    end
  end
  
  describe 'complex graph structures' do
    context 'Monitor -> Monitor -> Action chain' do
      let(:complex_config) do
        {
          'Name' => 'Complex Monitor Chain',
          'Graph' => [
            {
              'Name' => 'file_monitor',
              'Class' => 'CGE::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/source_file',
                'frequency' => 2
              }
            },
            {
              'Name' => 'socket_monitor',
              'Class' => 'CGE::UnixSocketMonitor',
              'Options' => {
                'socket_path' => '/tmp/webhook_{{file_monitor.time}}.sock'
              }
            },
            {
              'Name' => 'sms_action',
              'Class' => 'CGE::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'message' => 'File modified at {{file_monitor.time}}, webhook data: {{socket_monitor.data}}',
                'from' => '+0987654321',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(complex_config.to_json)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        current_command = graph.instance_variable_get(:@current_command)
        
        expect(current_command).to be_a(CGE::FileUpdateMonitor)
        expect(current_command.next_command).to be_a(CGE::UnixSocketMonitor)
        expect(current_command.next_command.next_command).to be_a(CGE::SMSAction)
      end
      
      it 'should preserve template substitution patterns' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        current_command = graph.instance_variable_get(:@current_command)
        
        socket_monitor_options = current_command.next_command.options
        expect(socket_monitor_options['socket_path']).to eq('/tmp/webhook_{{file_monitor.time}}.sock')
        
        sms_action_options = current_command.next_command.next_command.options
        expect(sms_action_options['message']).to eq('File modified at {{file_monitor.time}}, webhook data: {{socket_monitor.data}}')
      end
    end
    
    context 'Monitor -> Action -> Action chain' do
      let(:action_chain_config) do
        {
          'Name' => 'Action Chain Graph',
          'Graph' => [
            {
              'Name' => 'file_monitor',
              'Class' => 'CGE::FileUpdateMonitor',
              'Options' => {
                'path' => '/tmp/monitored_file',
                'frequency' => 5
              }
            },
            {
              'Name' => 'email_action',
              'Class' => 'CGE::EmailAction',
              'Options' => {
                'to' => 'admin@example.com',
                'subject' => 'File Update Alert',
                'body' => 'File updated at {{file_monitor.time}}',
                'from' => 'system@example.com',
                'server' => 'localhost'
              }
            },
            {
              'Name' => 'sms_action',
              'Class' => 'CGE::SMSAction',
              'Options' => {
                'to' => '+1234567890',
                'message' => 'Email sent: {{email_action.message_id}}',
                'from' => '+0987654321',
                'sid' => 'test_sid',
                'token' => 'test_token'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(action_chain_config.to_json)
        temp_file.close
      end
      
      it 'should create the correct chain structure' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        current_command = graph.instance_variable_get(:@current_command)
        
        expect(current_command).to be_a(CGE::FileUpdateMonitor)
        expect(current_command.next_command).to be_a(CGE::EmailAction)
        expect(current_command.next_command.next_command).to be_a(CGE::SMSAction)
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
            'base_path' => '/tmp/monitoring'
          },
          'Graph' => [
            {
              'Name' => 'file_monitor',
              'Class' => 'CGE::FileUpdateMonitor',
              'Options' => {
                'path' => '{{graph.base_path}}/watched_file',
                'frequency' => 5
              }
            },
            {
              'Name' => 'email_action',
              'Class' => 'CGE::EmailAction',
              'Options' => {
                'to' => '{{graph.admin_email}}',
                'subject' => 'Alert',
                'body' => 'File at {{graph.base_path}} was updated',
                'from' => 'system@example.com',
                'server' => 'localhost'
              }
            }
          ]
        }
      end
      
      before do
        temp_file.write(constants_config.to_json)
        temp_file.close
      end
      
      it 'should preserve {{graph.constant_name}} patterns in command options' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        current_command = graph.instance_variable_get(:@current_command)
        
        monitor_options = current_command.options
        expect(monitor_options['path']).to eq('{{graph.base_path}}/watched_file')
        
        email_options = current_command.next_command.options
        expect(email_options['to']).to eq('{{graph.admin_email}}')
        expect(email_options['body']).to eq('File at {{graph.base_path}} was updated')
      end
      
      it 'should correctly substitute constants when applying outputs' do
        graph = CGE::JSONCommandGraph.from_file(temp_file.path)
        current_command = graph.instance_variable_get(:@current_command)
        
        # Get the outputs which should include the constants
        outputs = graph.instance_variable_get(:@variables)
        expect(outputs['graph.admin_email']).to eq('admin@example.com')
        expect(outputs['graph.base_path']).to eq('/tmp/monitoring')
        
        # Apply outputs to monitor options
        monitor_options = graph.send(:substitute_variables, current_command.options, outputs)
        expect(monitor_options['path']).to eq('/tmp/monitoring/watched_file')
        
        # Apply outputs to email options
        email_options = graph.send(:substitute_variables, current_command.next_command.options, outputs)
        expect(email_options['to']).to eq('admin@example.com')
        expect(email_options['body']).to eq('File at /tmp/monitoring was updated')
      end
    end
  end
end