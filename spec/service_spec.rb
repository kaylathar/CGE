require 'spec_helper'
require 'cge/service'

describe CGE::Service do
  # Create a test service class that doesn't auto-register to avoid affecting other tests
  let(:test_service_class) do
    Class.new(CGE::Service) do
      attr_reader :perform_start_called, :perform_stop_called

      def initialize
        super
        @perform_start_called = false
        @perform_stop_called = false
      end

      protected

      def perform_start
        @perform_start_called = true
      end

      def perform_stop
        @perform_stop_called = true
      end

      # Override inherited to prevent auto-registration during tests
      def self.inherited(subclass)
        # Don't call super to avoid ServiceManager registration
      end
    end
  end

  let(:service) { test_service_class.new }

  describe '#initialize' do
    it 'initializes with stopped state' do
      expect(service.started?).to be false
    end
  end

  describe '#start' do
    it 'changes started state to true' do
      service.start
      expect(service.started?).to be true
    end

    it 'calls perform_start method' do
      service.start
      expect(service.perform_start_called).to be true
    end

    it 'does not start an already started service' do
      service.start
      expect(service.perform_start_called).to be true
      
      # Reset the flag and start again - perform_start should not be called again
      service.instance_variable_set(:@perform_start_called, false)
      service.start
      expect(service.perform_start_called).to be false
    end

    it 'is thread-safe for concurrent start calls' do
      call_count = 0
      allow(service).to receive(:perform_start) do
        call_count += 1
        sleep(0.01)
      end
      
      threads = 10.times.map do
        Thread.new { service.start }
      end
      
      threads.each(&:join)
      expect(call_count).to eq(1)
      expect(service.started?).to be true
    end
  end

  describe '#stop' do
    before { service.start }

    it 'changes started state to false' do
      service.stop
      expect(service.started?).to be false
    end

    it 'calls perform_stop method' do
      service.stop
      expect(service.perform_stop_called).to be true
    end

    it 'does not stop an already stopped service' do
      service.stop
      expect(service.perform_stop_called).to be true
      
      # Reset the flag and stop again - perform_stop should not be called again
      service.instance_variable_set(:@perform_stop_called, false)
      service.stop
      expect(service.perform_stop_called).to be false
    end

    it 'is thread-safe for concurrent stop calls' do
      call_count = 0
      allow(service).to receive(:perform_stop) do
        call_count += 1
        sleep(0.01)
      end
      
      threads = 10.times.map do
        Thread.new { service.stop }
      end
      
      threads.each(&:join)
      expect(call_count).to eq(1)
      expect(service.started?).to be false
    end
  end

  describe '#started?' do
    it 'returns false when service is not started' do
      expect(service.started?).to be false
    end

    it 'returns true after service starts' do
      service.start
      expect(service.started?).to be true
    end

    it 'returns false after service stops' do
      service.start
      service.stop
      expect(service.started?).to be false
    end
  end

  describe 'service lifecycle' do
    it 'can be restarted after stopping' do
      service.start
      expect(service.started?).to be true
      
      service.stop
      expect(service.started?).to be false
      
      service.start
      expect(service.started?).to be true
    end

    it 'maintains proper state through multiple start/stop cycles' do
      3.times do
        expect(service.started?).to be false
        service.start
        expect(service.started?).to be true
        service.stop
        expect(service.started?).to be false
      end
    end
  end
end