require 'cge/service'

module CGE
  # Service registry and locator for managing service lifecycle
  # Implements the Service Locator pattern with automatic service starting
  class ServiceManager
    def initialize
      @services = {}
      @mutex = Mutex.new
    end

    # Register a service class with a given name
    # @param name [Symbol] Service name identifier
    # @param service_class [Class] Service class that inherits from Service
    def self.register_service(name, service_class)
      raise ArgumentError, 'Service class must inherit from Service' unless service_class < Service

      service_class_mutex.synchronize do
        service_classes[name] = service_class
      end
    end

    def self.service_classes
      @service_classes ||= {}
    end

    def self.service_class_mutex
      @service_class_mutex ||= Mutex.new
    end

    # Lookup a service by name, creating and starting it if necessary
    # @param name [Symbol] Service name identifier
    # @param *args [Array] Arguments to pass to service constructor if creating new instance
    # @return [Service] The service instance
    def lookup(name, *args)
      @mutex.synchronize do
        # Return existing instance if already created and started
        return @services[name] if @services.key?(name) && @services[name].started?

        # Create new instance if we have the class registered
        service_class = nil
        self.class.service_class_mutex.synchronize do
          service_class = self.class.service_classes[name]
        end
        raise ArgumentError, "Service '#{name}' is not registered" unless service_class

        # Create and start the service
        service = service_class.new(*args)
        service.start
        @services[name] = service

        service
      end
    end

    # Stop and remove a service from the registry
    # @param name [Symbol] Service name identifier
    def stop_service(name)
      @mutex.synchronize do
        service = @services[name]
        if service
          service.stop
          @services.delete(name)
        end
      end
    end

    # Stop all services and clear the registry
    def stop_all_services
      @mutex.synchronize do
        @services.each_value(&:stop)
        @services.clear
      end
    end

    # Get list of registered service names
    # @return [Array<Symbol>] List of registered service names
    def registered_services
      self.class.service_class_mutex.synchronize do
        self.class.service_classes.keys
      end
    end

    # Get list of active service names
    # @return [Array<Symbol>] List of active service names
    def active_services
      @mutex.synchronize do
        @services.select { |_, service| service.started? }.keys
      end
    end
  end
end
