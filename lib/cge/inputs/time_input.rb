# frozen_string_literal: true

require 'cge/input'
require 'time'

module CGE
  # Input that provides current date/time information
  class TimeInput < Input
    # The format for the time output (default: ISO8601)
    attr_input 'format', String do |val|
      val.nil? || %w[iso8601 unix epoch rfc2822 custom].include?(val)
    end

    # Custom format string (used when format is 'custom')
    attr_input 'custom_format', String

    # @return [String] The current time in ISO8601 format
    attr_output :iso_time, String

    # @return [String] The current time in the requested format
    attr_output :formatted_time, String

    # @return [Integer] Unix timestamp
    attr_output :unix_timestamp, Integer

    # @return [String] Date only (YYYY-MM-DD)
    attr_output :date, String

    # @return [String] Time only (HH:MM:SS)
    attr_output :time_only, String

    # @return [Integer] Year
    attr_output :year, Integer

    # @return [Integer] Month (1-12)
    attr_output :month, Integer

    # @return [Integer] Day of month (1-31)
    attr_output :day, Integer

    # @return [Integer] Hour (0-23)
    attr_output :hour, Integer

    # @return [Integer] Minute (0-59)
    attr_output :minute, Integer

    # @return [Integer] Second (0-59)
    attr_output :second, Integer

    def invoke
      current_time = Time.now

      @iso_time = current_time.iso8601
      @formatted_time = format_time(current_time)
      @unix_timestamp = current_time.to_i
      @date = current_time.strftime('%Y-%m-%d')
      @time_only = current_time.strftime('%H:%M:%S')
      @year = current_time.year
      @month = current_time.month
      @day = current_time.day
      @hour = current_time.hour
      @minute = current_time.min
      @second = current_time.sec
    end

    private

    def format_time(time)
      format_type = format.value || 'iso8601'
      case format_type
      when 'unix', 'epoch'
        time.to_i.to_s
      when 'rfc2822'
        time.rfc2822
      when 'custom'
        time.strftime(custom_format.value || '%Y-%m-%d %H:%M:%S')
      else # 'iso8601' or default
        time.iso8601
      end
    end
  end
end

CGE::Command.register_command(CGE::TimeInput)
