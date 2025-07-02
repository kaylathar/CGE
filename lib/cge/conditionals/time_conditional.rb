# frozen_string_literal: true

require 'cge/conditional'
require 'cge/logging'
require 'time'

module CGE
  # A conditional that compares the current time with a specified time and
  # will not proceed further in Command graph if there is no match
  class TimeConditional < Conditional
    include Logging

    # The time to compare against 'now'
    attr_input 'time', String, :required do |val|
      !val.empty?
    end

    # The comparison operator: 'before', 'after', 'equal' (default: 'after')
    attr_input 'operator', String do |val|
      val.nil? || %w[before after equal].include?(val)
    end

    # Tolerance in seconds for 'equal' comparisons (default: 60)
    attr_input 'tolerance', Integer do |val|
      val.nil? || val >= 0
    end

    protected

    def determine_next_node(next_node)
      return next_node if time_condition_met?

      log_debug("Time condition #{self} failed, aborting graph execution")
      nil
    end

    private

    def time_condition_met?
      current_time = Time.now
      target_time = Time.parse(time.value)
      operation = operator.value || 'after'

      case operation
      when 'before'
        current_time < target_time
      when 'after'
        current_time > target_time
      when 'equal'
        tolerance_seconds = tolerance.value || 60
        (current_time - target_time).abs <= tolerance_seconds
      end
    end
  end
end

CGE::Command.register_command(CGE::TimeConditional)
