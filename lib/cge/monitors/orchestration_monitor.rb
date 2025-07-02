# frozen_string_literal: true

require 'cge/monitor'

module CGE
  # Monitors the orchestration service, waits for a message to this role
  class OrchestrationMonitor < Monitor
    attr_input :role, String, :required do |val|
      !val.empty?
    end

    attr_output :message, String

    def block_until_triggered
      orchestration_service = service_manager.lookup(:OrchestrationService)
      received_message = orchestration_service.block_for_message(role.value)

      @message = received_message

      log_info("Orchestration message received for role '#{role.value}': #{received_message}")
    end
  end
end

CGE::Command.register_command(CGE::OrchestrationMonitor)
