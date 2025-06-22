require 'cge/monitor'
require 'time'

module CGE
  # Monitor that fires once at a specific time, then stops
  class CronMonitor < Monitor
    attr_option :time, String, :required do |val|
      begin
        Time.parse(val)
        true
      rescue ArgumentError
        false
      end
    end

    # @return [Time] The time when the monitor fired
    attr_output :fired_at, Time

    def block_until_triggered
      @target_time = Time.parse(@time.value)

      current_time = Time.now
      return if current_time >= @target_time

      sleep_duration = @target_time - current_time
      sleep(sleep_duration) if sleep_duration > 0

      @fired_at = Time.now
    end
  end
end
