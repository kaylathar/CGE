# rubocop:disable Style/ClassVars

module CGE
  # Module used for configurable objects internally
  # adds the has_input class method that creates an input
  # for use on Monitor and Action subclasses - it exposes
  # the inputs that are present, and required types, so that
  # parsers and UI can view them if required
  module Configurable
    # Processes given parameter into the defined inputs previously declared
    # includes validation for types and any custom validators delcared
    #
    # @param [Hash<String,Object>] Hash of input name/value pairs, values
    # must conform to validation rules for inputs or exception will be raised
    def process_inputs(inputs, ignore_extras: false)
      inputs.each do |key, value|
        key = key.to_s
        next if ignore_extras && self.class.inputs[key]
        raise InputError, "No Input #{key}" unless self.class.inputs[key]

        input = send(key.to_s)
        input.value = value
        raise InputError, "Bad value for input #{key}" unless input.valid?
      end
      validate_required_inputs
    end

    def validate_required_inputs
      self.class.send('required_inputs').each do |name|
        input = send(name.to_s)
        unless input.valid?
          raise InputError,
                "Required input #{name} missing or invalid"
        end
      end
    end

    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    private :validate_required_inputs
    protected :process_inputs

    # Class methods used by configurable classes
    module ClassMethods
      def setup_inputs
        class_variable_get('@@inputs')
        class_variable_get('@@required_inputs')
      rescue StandardError
        class_variable_set('@@inputs', {})
        class_variable_set('@@required_inputs', [])
      end

      def setup_input(name, type, required, verifier)
        define_method(name.to_s) do
          unless instance_variable_get("@#{name}")
            instance_variable_set("@#{name}",
                                  InputOption.new(name, type, verifier))
          end
          instance_variable_get("@#{name}")
        end

        class_variable_get('@@required_inputs') << name if
          required == :required
        class_variable_get('@@inputs')[name] = type
      end

      def setup_outputs
        class_variable_get('@@outputs')
      rescue StandardError
        class_variable_set('@@outputs', {})
      end

      def setup_output(name, type)
        define_method(name.to_s) do
          instance_variable_get("@#{name}")
        end
        class_variable_get('@@outputs')[name] = type
      end

      # Notes that this class has the specified input
      #
      # @param [String, Symbol] name Name of this input
      # @param [Class] type Type required for this input - will be verified
      # @param [optional, :optional, :required] required Is this input
      # required to be set, or merely optional
      def attr_input(name, type, required = :optional, &verifier)
        name = name.to_s
        setup_inputs
        setup_input(name, type, required, verifier)
      end

      def attr_output(name, type)
        name = name.to_s
        setup_outputs
        setup_output(name, type)
      end

      # Returns required set of inputs
      # @return [Array<InputOption>] Required inputs for this class
      def required_inputs
        class_variable_get('@@required_inputs')
      end

      # Returns valid set of inputs
      # @return [Hash<String,Class>] Available set of inputs, with expected
      # class for each.
      def inputs
        class_variable_get('@@inputs')
      end

      # Returns set of outputs that are set
      # @return [Hash<String,Class>]] Outputs that are set on trigger, with
      # types of each as values
      def outputs
        setup_outputs
      end

      protected :attr_input, :attr_output
      private :setup_inputs, :setup_input, :setup_output, :setup_outputs
    end
  end

  # Used to store inputs - includes the expected type
  # the name, and the value.  Also includes validation logic
  # - the absence of validation logic in the value= operator is
  # intentional, as there may be cases where you can set an invalid
  # input value
  class InputOption
    attr_reader :name, :type
    attr_accessor :value

    def initialize(name, type, verifier = nil)
      @type = type
      @name = name
      @verifier = verifier || true
    end

    def valid?
      !@value.nil? && @value.is_a?(@type) &&
        (@verifier == true || @verifier.call(@value))
    end
  end

  class InputError < StandardError
  end
end
# rubocop:enable Style/ClassVars
