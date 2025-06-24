require 'spec_helper'
require 'cge/service_manager'

describe CGE::ServiceManager do
  let(:service_manager) { CGE::ServiceManager.new }

  # Clear class-level service registry before each test
  before do
    CGE::ServiceManager.service_classes.clear
  end

  let(:test_service_class) do
    Class.new(CGE::Service) do
      attr_reader :constructor_args, :start_called, :stop_called

      def initialize(*args)
        super()
        @constructor_args = args
        @start_called = false
        @stop_called = false
      end

      protected

      def perform_start
        @start_called = true
      end

      def perform_stop
        @stop_called = true
      end
    end
  end

  let(:another_service_class) do
    Class.new(CGE::Service) do
      attr_reader :value

      def initialize(value)
        super()
        @value = value
      end
    end
  end

  describe '#initialize' do
    it 'creates empty service registry' do
      expect(service_manager.registered_services).to be_empty
      expect(service_manager.active_services).to be_empty
    end
  end

  describe '.register_service' do
    it 'registers a service class' do
      CGE::ServiceManager.register_service(:test_service, test_service_class)
      expect(service_manager.registered_services).to include(:test_service)
    end

    it 'raises error for non-service classes' do
      expect {
        CGE::ServiceManager.register_service(:invalid, String)
      }.to raise_error(ArgumentError, 'Service class must inherit from Service')
    end

    it 'allows registering multiple services' do
      CGE::ServiceManager.register_service(:test_service, test_service_class)
      CGE::ServiceManager.register_service(:another_service, another_service_class)
      
      expect(service_manager.registered_services).to contain_exactly(:test_service, :another_service)
    end
  end

  describe '#lookup' do
    before do
      CGE::ServiceManager.register_service(:test_service, test_service_class)
    end

    it 'creates and starts a new service instance' do
      service = service_manager.lookup(:test_service)
      
      expect(service).to be_a(test_service_class)
      expect(service.started?).to be true
      expect(service.start_called).to be true
    end

    it 'passes constructor arguments to service' do
      CGE::ServiceManager.register_service(:parameterized_service, another_service_class)
      service = service_manager.lookup(:parameterized_service, 'test_value')
      
      expect(service.value).to eq('test_value')
    end

    it 'returns existing started service instance' do
      service1 = service_manager.lookup(:test_service)
      service2 = service_manager.lookup(:test_service)
      
      expect(service1).to be(service2)
    end

    it 'raises error for unregistered service' do
      expect {
        service_manager.lookup(:unregistered_service)
      }.to raise_error(ArgumentError, "Service 'unregistered_service' is not registered")
    end

    it 'creates new instance if existing service is stopped' do
      service1 = service_manager.lookup(:test_service)
      service1.stop
      
      service2 = service_manager.lookup(:test_service)
      
      expect(service1).not_to be(service2)
      expect(service1.started?).to be false
      expect(service2.started?).to be true
    end

    it 'is thread-safe for concurrent lookups' do
      services = []
      
      threads = 10.times.map do
        Thread.new do
          services << service_manager.lookup(:test_service)
        end
      end
      
      threads.each(&:join)
      
      expect(services).to all(be_a(test_service_class))
      expect(services.uniq.length).to eq(1) # All should be the same instance
    end
  end

  describe '#stop_service' do
    before do
      CGE::ServiceManager.register_service(:test_service, test_service_class)
    end

    it 'stops and removes service from registry' do
      service = service_manager.lookup(:test_service)
      expect(service.started?).to be true
      
      service_manager.stop_service(:test_service)
      
      expect(service.started?).to be false
      expect(service.stop_called).to be true
      expect(service_manager.get(:test_service)).to be_nil
    end

    it 'handles stopping non-existent service gracefully' do
      expect {
        service_manager.stop_service(:nonexistent)
      }.not_to raise_error
    end
  end

  describe '#stop_all_services' do
    before do
      CGE::ServiceManager.register_service(:test_service, test_service_class)
      CGE::ServiceManager.register_service(:another_service, another_service_class)
    end

    it 'stops all active services and clears registry' do
      service1 = service_manager.lookup(:test_service)
      service2 = service_manager.lookup(:another_service, 'test')
      
      expect(service1.started?).to be true
      expect(service2.started?).to be true
      
      service_manager.stop_all_services
      
      expect(service1.started?).to be false
      expect(service2.started?).to be false
      expect(service_manager.active_services).to be_empty
    end

    it 'handles empty service registry gracefully' do
      expect {
        service_manager.stop_all_services
      }.not_to raise_error
    end
  end

  describe '#registered_services' do
    it 'returns empty array initially' do
      expect(service_manager.registered_services).to eq([])
    end

    it 'returns list of registered service names' do
      CGE::ServiceManager.register_service(:service1, test_service_class)
      CGE::ServiceManager.register_service(:service2, another_service_class)
      
      expect(service_manager.registered_services).to contain_exactly(:service1, :service2)
    end
  end

  describe '#active_services' do
    before do
      CGE::ServiceManager.register_service(:test_service, test_service_class)
      CGE::ServiceManager.register_service(:another_service, another_service_class)
    end

    it 'returns empty array initially' do
      expect(service_manager.active_services).to eq([])
    end

    it 'returns list of started service names' do
      service_manager.lookup(:test_service)
      service_manager.lookup(:another_service, 'test')
      
      expect(service_manager.active_services).to contain_exactly(:test_service, :another_service)
    end

    it 'excludes stopped services' do
      service_manager.lookup(:test_service)
      service_manager.lookup(:another_service, 'test')
      service_manager.stop_service(:test_service)
      
      expect(service_manager.active_services).to contain_exactly(:another_service)
    end
  end

  describe 'service lifecycle integration' do
    before do
      CGE::ServiceManager.register_service(:test_service, test_service_class)
    end

    it 'manages complete service lifecycle' do
      # Initial state
      expect(service_manager.active_services).to be_empty
      
      # Start service
      service = service_manager.lookup(:test_service)
      expect(service.started?).to be true
      expect(service_manager.active_services).to include(:test_service)
      
      # Stop service
      service_manager.stop_service(:test_service)
      expect(service.started?).to be false
      expect(service_manager.active_services).to be_empty
      
      # Restart service
      new_service = service_manager.lookup(:test_service)
      expect(new_service.started?).to be true
      expect(new_service).not_to be(service) # Different instance
      expect(service_manager.active_services).to include(:test_service)
    end
  end
end