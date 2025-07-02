# frozen_string_literal: true

require 'cge/service'
require 'cge/logging'
require 'cge/service_manager'

module CGE
  # Service providing orchestration between graphs
  class OrchestrationService < Service
    include Logging

    def initialize
      super
      @message_queues = {}
      @queue_mutex = Mutex.new
      @condition_variables = {}
      @condition_variables_mutex = Mutex.new
    end

    def send_message(role, message)
      @queue_mutex.synchronize do
        @message_queues[role] ||= []
        @message_queues[role] << message

        log_info("Sent message to role '#{role}': #{message}")

        @condition_variables_mutex.synchronize do
          conditional_variable = @condition_variables[role]
          conditional_variable&.signal
        end
      end
    end

    def block_for_message(role)
      message = nil

      @queue_mutex.synchronize do
        while @message_queues[role].nil? || @message_queues[role].empty?
          @condition_variables_mutex.synchronize do
            @condition_variables[role] ||= ConditionVariable.new
            conditional_variable = @condition_variables[role]

            @queue_mutex.unlock
            conditional_variable.wait(@condition_variables_mutex)
            @queue_mutex.lock
          end
        end

        message = @message_queues[role].shift
        log_info("Received message for role '#{role}': #{message}")
      end

      message
    end

    def peek_message(role)
      @queue_mutex.synchronize do
        return nil if @message_queues[role].nil? || @message_queues[role].empty?

        @message_queues[role].first
      end
    end

    def messages?(role)
      @queue_mutex.synchronize do
        !(@message_queues[role].nil? || @message_queues[role].empty?)
      end
    end

    def clear_messages(role)
      @queue_mutex.synchronize do
        cleared_count = @message_queues[role]&.size || 0
        @message_queues[role] = []
        log_info("Cleared #{cleared_count} messages for role '#{role}'")
        cleared_count
      end
    end

    def get_queue_size(role)
      @queue_mutex.synchronize do
        @message_queues[role]&.size || 0
      end
    end

    def list_roles
      @queue_mutex.synchronize do
        @message_queues.keys
      end
    end

    protected

    def perform_start
      log_info('OrchestrationService started')
    end

    def perform_stop
      @queue_mutex.synchronize do
        @message_queues.clear
      end

      @condition_variables_mutex.synchronize do
        @condition_variables.each_value(&:broadcast)
        @condition_variables.clear
      end

      log_info('OrchestrationService stopped')
    end
  end
end

CGE::ServiceManager.register_service(:OrchestrationService, CGE::OrchestrationService)
