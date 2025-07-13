# frozen_string_literal: true

require 'cge/conditional'
require 'cge/logging'

module CGE
  # A conditional that checks if a value is included in or excluded from a set,
  # if condition is not met will not proceed to next Command in graph
  class InclusionConditional < Conditional
    include Logging

    # The value to check for inclusion/exclusion
    attr_input 'value', String, :required do |val|
      !val.empty?
    end

    # The set of values to check against (comma-separated string)
    attr_input 'set', String, :required do |val|
      !val.empty?
    end

    # The operation: 'include' or 'exclude' (default: 'include')
    attr_input 'operation', String do |val|
      val.nil? || %w[include exclude].include?(val)
    end

    # Whether to perform case-sensitive matching (default: false)
    attr_input 'case_sensitive', Object

    protected

    def determine_next_node(next_node, _command_graph)
      return next_node if inclusion_condition_met?

      log_debug("Inclusion condition #{self} failed, aborting graph execution")
      nil
    end

    private

    def inclusion_condition_met?
      target_value = case_sensitive.value ? value.value : value.value.downcase
      value_set = parse_set(set.value)
      operation_type = operation.value || 'include'

      case operation_type
      when 'include'
        value_set.include?(target_value)
      when 'exclude'
        !value_set.include?(target_value)
      end
    end

    def parse_set(set_string)
      values = set_string.split(',').map(&:strip)
      if case_sensitive.value
        values
      else
        values.map(&:downcase)
      end
    end
  end
end

CGE::Command.register_command(CGE::InclusionConditional)
