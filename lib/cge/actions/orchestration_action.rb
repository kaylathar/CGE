# frozen_string_literal: true

require 'cge/action'

module CGE
  # An action to send messages via the orchestration service
  class OrchestrationAction < Action
    attr_input :role, String, :required
    attr_input :message, String, :required

    def invoke
      orchestration_service = service_manager.lookup(:OrchestrationService)
      orchestration_service.send_message(role.value, message.value)
      log_info("Orchestration message sent to role '#{role.value}': #{message.value}")
    end
  end
end

CGE::Command.register_command(CGE::OrchestrationAction)
