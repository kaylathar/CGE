# frozen_string_literal: true

require 'cge/conditional'
require 'cge/logging'

module CGE
  # A conditional that compares two values using various operators
  # Halts execution if the condition is not met
  class ComparisonConditional < Conditional
    include Logging

    attr_input 'value1', String, :required
    attr_input 'value2', String, :required
    attr_input 'operator', String do |val|
      %w[eq ne gt lt gte lte].include?(val)
    end

    protected

    def determine_next_node(next_node)
      return next_node if compute_comparison_result(value1.value, value2.value)

      log_debug("Comparison #{self} failed, aborting graph execution")
      nil
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def compute_comparison_result(val1, val2)
      op = operator.value || 'eq'

      case op
      when 'eq'
        val1 == val2
      when 'ne'
        val1 != val2
      when 'gt'
        numeric_compare(val1, val2) { |n1, n2| n1 > n2 }
      when 'lt'
        numeric_compare(val1, val2) { |n1, n2| n1 < n2 }
      when 'gte'
        numeric_compare(val1, val2) { |n1, n2| n1 >= n2 }
      when 'lte'
        numeric_compare(val1, val2) { |n1, n2| n1 <= n2 }
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def numeric_compare(val1, val2)
      num1, num2 = parse_numbers(val1, val2)
      yield(num1, num2)
    end

    def regex_match(val1, val2)
      val1.match?(Regexp.new(val2))
    rescue RegexpError => e
      raise ComparisonConditionalError, "Invalid regex pattern: #{e.message}"
    end

    def parse_numbers(val1, val2)
      [val1, val2].map do |val|
        Float(val)
      end
    end
  end

  class ComparisonConditionalError < StandardError
  end
end
CGE::Command.register_command(CGE::ComparisonConditional)
