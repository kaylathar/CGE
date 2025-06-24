require 'cge/service_manager'

module CGE
  # Represents a persistent service that can run to support
  # the overall CGE system or any plugin thereof.
  class Service
    attr_reader :started

    def initialize
      @started = false
      @mutex = Mutex.new
    end

    # Start the service if it's not already started. Can be called
    # from multiple threads safely.
    def start
      @mutex.synchronize do
        return if @started

        perform_start
        @started = true
      end
    end

    # Stop the service if it's currently started. Can be called
    # from multiple threads safely.
    def stop
      @mutex.synchronize do
        return unless @started

        perform_stop
        @started = false
      end
    end

    # Check if the service is currently started. Can be called
    # from multiple threads safely.
    def started?
      @mutex.synchronize do
        return @started
      end
    end

    # Hook to automatically register service classes when they're defined
    def self.inherited(subclass)
      super
      ServiceManager.register_service(subclass.name.to_sym, subclass) if subclass.name
    end
  end
end
