# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/monitors/orchestration_monitor'

RSpec.describe CGE::OrchestrationMonitor do
  let(:service_manager) { instance_double('CGE::ServiceManager') }
  let(:orchestration_service) { instance_double('CGE::OrchestrationService') }
  let(:monitor) { described_class.new('monitor_id', 'test_monitor', {}, nil, nil, service_manager) }

  before do
    allow(service_manager).to receive(:lookup).with(:OrchestrationService).and_return(orchestration_service)
  end

  describe '#block_until_triggered' do
    context 'with valid inputs and no timeout' do
      before do
        monitor.send(:process_inputs, { 'role' => 'test_role' })
      end

      it 'gets the orchestration service from service manager' do
        expect(service_manager).to receive(:lookup).with(:OrchestrationService)
        allow(orchestration_service).to receive(:block_for_message).and_return('test message')
        
        monitor.block_until_triggered
      end

      it 'blocks for message on the specified role' do
        expect(orchestration_service).to receive(:block_for_message).with('test_role').and_return('received message')
        
        monitor.block_until_triggered
        expect(monitor.message).to eq('received message')
      end

      it 'sets the message output attribute' do
        allow(orchestration_service).to receive(:block_for_message).and_return('output message')
        
        monitor.block_until_triggered
        expect(monitor.message).to eq('output message')
      end

      it 'handles different message types' do
        json_message = { task: 'complete', id: 123 }.to_json
        allow(orchestration_service).to receive(:block_for_message).and_return(json_message)
        
        monitor.block_until_triggered
        expect(monitor.message).to eq(json_message)
      end

      it 'handles empty messages' do
        allow(orchestration_service).to receive(:block_for_message).and_return('')
        
        monitor.block_until_triggered
        expect(monitor.message).to eq('')
      end

      it 'handles unicode messages' do
        unicode_message = 'Сообщение 🎉 메시지'
        allow(orchestration_service).to receive(:block_for_message).and_return(unicode_message)
        
        monitor.block_until_triggered
        expect(monitor.message).to eq(unicode_message)
      end

      it 'handles very long messages' do
        long_message = 'a' * 10000
        allow(orchestration_service).to receive(:block_for_message).and_return(long_message)
        
        monitor.block_until_triggered
        expect(monitor.message).to eq(long_message)
      end
    end

    context 'when orchestration service is unavailable' do
      before do
        allow(service_manager).to receive(:lookup).with(:OrchestrationService).and_return(nil)
        monitor.send(:process_inputs, { 'role' => 'test_role' })
      end

      it 'raises an error when orchestration service is not available' do
        expect { monitor.block_until_triggered }.to raise_error(NoMethodError)
      end
    end

    context 'when service operations fail' do
      before do
        monitor.send(:process_inputs, { 'role' => 'test_role' })
      end

      it 'handles block_for_message failure gracefully' do
        allow(orchestration_service).to receive(:block_for_message).and_raise(StandardError, 'Blocking failed')
        expect { monitor.block_until_triggered }.to raise_error(StandardError, 'Blocking failed')
      end

      it 'handles service returning unexpected types' do
        allow(orchestration_service).to receive(:block_for_message).and_return(12345)
        
        monitor.block_until_triggered
        expect(monitor.message).to eq(12345)
      end

      it 'handles service returning nil' do
        allow(orchestration_service).to receive(:block_for_message).and_return(nil)
        
        monitor.block_until_triggered
        expect(monitor.message).to be_nil
      end
    end
  end

  describe 'input validation' do
    it 'requires role input' do
      expect { monitor.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input role/)
    end

    it 'validates role is not empty when provided' do
      expect { 
        monitor.send(:process_inputs, { 'role' => '' }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates role is a string' do
      expect { 
        monitor.send(:process_inputs, { 'role' => 12345 }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid role input' do
      expect { 
        monitor.send(:process_inputs, { 'role' => 'valid_role' }) 
      }.not_to raise_error
    end

    it 'accepts role with special characters' do
      expect { 
        monitor.send(:process_inputs, { 'role' => 'role-with_special.chars@123' }) 
      }.not_to raise_error
    end

    it 'accepts unicode role names' do
      expect { 
        monitor.send(:process_inputs, { 'role' => '角色_🎭_роль' }) 
      }.not_to raise_error
    end

    it 'accepts very long role names' do
      long_role = 'a' * 1000
      expect { 
        monitor.send(:process_inputs, { 'role' => long_role }) 
      }.not_to raise_error
    end
  end

  describe 'output attributes' do
    before do
      monitor.send(:process_inputs, { 'role' => 'test_role' })
    end

    it 'provides access to message output' do
      expect(monitor).to respond_to(:message)
    end

    it 'initially has nil message' do
      expect(monitor.message).to be_nil
    end

    it 'sets message after blocking completes' do
      allow(orchestration_service).to receive(:block_for_message).and_return('test output')
      
      monitor.block_until_triggered
      expect(monitor.message).to eq('test output')
    end
  end

  describe 'blocking behavior' do
    before do
      monitor.send(:process_inputs, { 'role' => 'blocking_test_role' })
    end

    it 'actually blocks until message is received' do
      start_time = Time.now
      message_delivered = false
      
      # Simulate the service blocking for a short time
      allow(orchestration_service).to receive(:block_for_message) do
        sleep(0.1) # Simulate blocking
        message_delivered = true
        'delayed message'
      end
      
      monitor.block_until_triggered
      elapsed_time = Time.now - start_time
      
      expect(message_delivered).to be true
      expect(elapsed_time).to be >= 0.1
      expect(monitor.message).to eq('delayed message')
    end

    it 'handles rapid successive calls correctly' do
      call_count = 0
      allow(orchestration_service).to receive(:block_for_message) do
        call_count += 1
        "message_#{call_count}"
      end
      
      first_result = nil
      second_result = nil
      
      first_thread = Thread.new do
        first_monitor = described_class.new('monitor1', 'test_monitor', {}, nil, nil, service_manager)
        first_monitor.send(:process_inputs, { 'role' => 'test_role' })
        first_monitor.block_until_triggered
        first_result = first_monitor.message
      end
      
      second_thread = Thread.new do
        second_monitor = described_class.new('monitor2', 'test_monitor', {}, nil, nil, service_manager)
        second_monitor.send(:process_inputs, { 'role' => 'test_role' })
        second_monitor.block_until_triggered
        second_result = second_monitor.message
      end
      
      first_thread.join
      second_thread.join
      
      expect(first_result).to match(/message_\d/)
      expect(second_result).to match(/message_\d/)
      expect(call_count).to eq(2)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent monitors safely' do
      results = []
      threads = []
      
      allow(orchestration_service).to receive(:block_for_message) do |role|
        "message_for_#{role}"
      end
      
      5.times do |i|
        threads << Thread.new do
          thread_monitor = described_class.new("monitor_#{i}", 'test_monitor', {}, nil, nil, service_manager)
          thread_monitor.send(:process_inputs, { 'role' => "role_#{i}" })
          thread_monitor.block_until_triggered
          results << thread_monitor.message
        end
      end
      
      threads.each(&:join)
      
      expect(results.size).to eq(5)
      results.each_with_index do |result, i|
        expect(result).to eq("message_for_role_#{i}")
      end
    end

    it 'maintains input isolation between concurrent monitors' do
      monitor1 = described_class.new('monitor1', 'test_monitor', {}, nil, nil, service_manager)
      monitor2 = described_class.new('monitor2', 'test_monitor', {}, nil, nil, service_manager)
      
      monitor1.send(:process_inputs, { 'role' => 'role1' })
      monitor2.send(:process_inputs, { 'role' => 'role2' })
      
      allow(orchestration_service).to receive(:block_for_message) do |role|
        "specific_message_for_#{role}"
      end
      
      result1 = nil
      result2 = nil
      
      thread1 = Thread.new do
        monitor1.block_until_triggered
        result1 = monitor1.message
      end
      
      thread2 = Thread.new do
        monitor2.block_until_triggered
        result2 = monitor2.message
      end
      
      thread1.join
      thread2.join
      
      expect(result1).to eq('specific_message_for_role1')
      expect(result2).to eq('specific_message_for_role2')
    end
  end

  describe 'error handling edge cases' do
    it 'handles nil role gracefully during validation' do
      expect { 
        monitor.send(:process_inputs, { 'role' => nil }) 
      }.to raise_error(CGE::InputError)
    end

    it 'handles service lookup returning wrong type' do
      wrong_service = double('WrongService')
      allow(service_manager).to receive(:lookup).and_return(wrong_service)
      allow(wrong_service).to receive(:block_for_message).and_raise(NoMethodError, 'undefined method')
      monitor.send(:process_inputs, { 'role' => 'test_role' })
      
      expect { monitor.block_until_triggered }.to raise_error(NoMethodError)
    end

    it 'handles unexpected service responses gracefully' do
      allow(orchestration_service).to receive(:block_for_message).and_return(['array', 'response'])
      
      monitor.send(:process_inputs, { 'role' => 'test_role' })
      monitor.block_until_triggered
      
      expect(monitor.message).to eq(['array', 'response'])
    end
  end

  describe 'integration scenarios' do
    it 'works with role names containing whitespace' do
      monitor.send(:process_inputs, { 'role' => 'role with spaces' })
      allow(orchestration_service).to receive(:block_for_message).with('role with spaces').and_return('spaced message')
      
      monitor.block_until_triggered
      expect(monitor.message).to eq('spaced message')
    end

    it 'works with complex nested data structures' do
      complex_data = {
        'nested' => {
          'array' => [1, 2, { 'deep' => 'value' }],
          'string' => 'test'
        }
      }
      
      monitor.send(:process_inputs, { 'role' => 'complex_role' })
      allow(orchestration_service).to receive(:block_for_message).and_return(complex_data)
      
      monitor.block_until_triggered
      expect(monitor.message).to eq(complex_data)
    end
  end
end