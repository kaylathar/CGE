# frozen_string_literal: true

require 'cge/monitor'

module CGE
  # Monitor that waits for a specified duration before triggering
  class WaitMonitor < Monitor
    # Duration to wait in seconds
    attr_input :duration, Integer, :required, &:positive?

    def block_until_triggered
      sleep(duration.value)
    end
  end
end

CGE::Command.register_command(CGE::WaitMonitor)
