# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/actions/orchestration_action'

RSpec.describe CGE::OrchestrationAction do
  let(:service_manager) { instance_double('CGE::ServiceManager') }
  let(:orchestration_service) { instance_double('CGE::OrchestrationService') }
  let(:action) { described_class.new('action_id', 'test_action', {}, nil, nil, service_manager) }

  before do
    allow(service_manager).to receive(:lookup).with(:OrchestrationService).and_return(orchestration_service)
    allow(orchestration_service).to receive(:send_message)
  end

  describe '#invoke' do
    context 'with valid inputs' do
      before do
        action.send(:process_inputs, {
          'role' => 'worker_role',
          'message' => 'Start processing task 123'
        })
      end

      it 'gets the orchestration service from service manager' do
        expect(service_manager).to receive(:lookup).with(:OrchestrationService)
        action.invoke
      end

      it 'sends message to the specified role' do
        expect(orchestration_service).to receive(:send_message).with('worker_role', 'Start processing task 123')
        action.invoke
      end

      it 'handles different role names' do
        action.send(:process_inputs, {
          'role' => 'data_processor',
          'message' => 'Process data batch 456'
        })
        
        expect(orchestration_service).to receive(:send_message).with('data_processor', 'Process data batch 456')
        action.invoke
      end

      it 'handles complex messages' do
        complex_message = {
          'task_id' => 123,
          'action' => 'process',
          'data' => ['item1', 'item2']
        }.to_json
        
        action.send(:process_inputs, {
          'role' => 'json_processor',
          'message' => complex_message
        })
        
        expect(orchestration_service).to receive(:send_message).with('json_processor', complex_message)
        action.invoke
      end

      it 'handles multiline messages' do
        multiline_message = "Line 1\nLine 2\nLine 3"
        action.send(:process_inputs, {
          'role' => 'multiline_role',
          'message' => multiline_message
        })
        
        expect(orchestration_service).to receive(:send_message).with('multiline_role', multiline_message)
        action.invoke
      end

      it 'handles empty messages' do
        action.send(:process_inputs, {
          'role' => 'empty_role',
          'message' => ''
        })
        
        expect(orchestration_service).to receive(:send_message).with('empty_role', '')
        action.invoke
      end

      it 'handles roles with special characters' do
        action.send(:process_inputs, {
          'role' => 'role-with_special.chars@123',
          'message' => 'test message'
        })
        
        expect(orchestration_service).to receive(:send_message).with('role-with_special.chars@123', 'test message')
        action.invoke
      end
    end

    context 'when orchestration service is unavailable' do
      before do
        allow(service_manager).to receive(:lookup).with(:OrchestrationService).and_return(nil)
        action.send(:process_inputs, {
          'role' => 'test_role',
          'message' => 'test message'
        })
      end

      it 'raises an error when orchestration service is not available' do
        expect { action.invoke }.to raise_error(NoMethodError)
      end
    end

    context 'when service operations fail' do
      before do
        action.send(:process_inputs, {
          'role' => 'test_role',
          'message' => 'test message'
        })
      end

      it 'handles send_message failure gracefully' do
        allow(orchestration_service).to receive(:send_message).and_raise(StandardError, 'Send failed')
        expect { action.invoke }.to raise_error(StandardError, 'Send failed')
      end

      it 'handles service lookup returning wrong type' do
        wrong_service = double('WrongService')
        allow(service_manager).to receive(:lookup).and_return(wrong_service)
        allow(wrong_service).to receive(:send_message).and_raise(NoMethodError, 'wrong service')
        expect { action.invoke }.to raise_error(NoMethodError, 'wrong service')
      end
    end
  end

  describe 'input validation' do
    it 'requires role input' do
      expect { 
        action.send(:process_inputs, { 'message' => 'test message' }) 
      }.to raise_error(CGE::InputError, /Required input role/)
    end

    it 'requires message input' do
      expect { 
        action.send(:process_inputs, { 'role' => 'test_role' }) 
      }.to raise_error(CGE::InputError, /Required input message/)
    end

    it 'validates role is a string' do
      expect { 
        action.send(:process_inputs, { 
          'role' => 12345, 
          'message' => 'test message' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates message is a string' do
      expect { 
        action.send(:process_inputs, { 
          'role' => 'test_role', 
          'message' => 12345 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs' do
      expect { 
        action.send(:process_inputs, { 
          'role' => 'valid_role', 
          'message' => 'valid message' 
        }) 
      }.not_to raise_error
    end

    it 'accepts empty strings for role and message' do
      expect { 
        action.send(:process_inputs, { 
          'role' => '', 
          'message' => '' 
        }) 
      }.not_to raise_error
    end
  end

  describe 'integration scenarios' do
    it 'works with unicode roles and messages' do
      unicode_role = '角色_🎭_роль'
      unicode_message = 'Сообщение 메시지 📨 رسالة'
      
      action.send(:process_inputs, {
        'role' => unicode_role,
        'message' => unicode_message
      })
      
      expect(orchestration_service).to receive(:send_message).with(unicode_role, unicode_message)
      action.invoke
    end

    it 'works with very long role names and messages' do
      long_role = 'a' * 1000
      long_message = 'b' * 10000
      
      action.send(:process_inputs, {
        'role' => long_role,
        'message' => long_message
      })
      
      expect(orchestration_service).to receive(:send_message).with(long_role, long_message)
      action.invoke
    end

    it 'works with whitespace-only inputs' do
      action.send(:process_inputs, {
        'role' => '   \t\n   ',
        'message' => '   \t\n   '
      })
      
      expect(orchestration_service).to receive(:send_message).with('   \t\n   ', '   \t\n   ')
      action.invoke
    end
  end

  describe 'thread safety' do
    it 'handles concurrent invocations safely' do
      action.send(:process_inputs, {
        'role' => 'concurrent_role',
        'message' => 'concurrent message'
      })

      allow(orchestration_service).to receive(:send_message)
      
      threads = []
      results = []
      
      10.times do |i|
        threads << Thread.new do
          # Each thread uses slightly different inputs
          thread_action = described_class.new("action_#{i}", 'test_action', {}, nil, nil, service_manager)
          thread_action.send(:process_inputs, {
            'role' => "role_#{i}",
            'message' => "message_#{i}"
          })
          results << thread_action.invoke
        end
      end
      
      threads.each(&:join)
      expect(results.size).to eq(10)
    end

    it 'maintains input isolation between concurrent invocations' do
      call_log = []
      allow(orchestration_service).to receive(:send_message) do |role, message|
        call_log << { role: role, message: message }
      end
      
      threads = []
      
      5.times do |i|
        threads << Thread.new do
          thread_action = described_class.new("action_#{i}", 'test_action', {}, nil, nil, service_manager)
          thread_action.send(:process_inputs, {
            'role' => "unique_role_#{i}",
            'message' => "unique_message_#{i}"
          })
          thread_action.invoke
        end
      end
      
      threads.each(&:join)
      
      expect(call_log.size).to eq(5)
      # Verify each call had unique parameters
      roles = call_log.map { |call| call[:role] }
      messages = call_log.map { |call| call[:message] }
      expect(roles.uniq.size).to eq(5)
      expect(messages.uniq.size).to eq(5)
    end
  end

  describe 'error handling edge cases' do
    it 'handles nil role gracefully during validation' do
      expect { 
        action.send(:process_inputs, { 
          'role' => nil, 
          'message' => 'test' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'handles nil message gracefully during validation' do
      expect { 
        action.send(:process_inputs, { 
          'role' => 'test', 
          'message' => nil 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'handles service returning unexpected responses' do
      allow(orchestration_service).to receive(:send_message).and_return(nil)
      
      action.send(:process_inputs, {
        'role' => 'test_role',
        'message' => 'test_message'
      })
      
      expect { action.invoke }.not_to raise_error
    end
  end
end