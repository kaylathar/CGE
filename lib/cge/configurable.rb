# rubocop:disable Style/ClassVars

module CGE
  # Module used for configurable objects internally
  # adds the has_option class method that creates an option
  # for use on Monitor and Action subclasses - it exposes
  # the options that are present, and required types, so that
  # parsers and UI can view them if required
  module Configurable
    # Processes given parameter into the defined options previously declared
    # includes validation for types and any custom validators delcared
    #
    # @param [Hash<String,Object>] Hash of option name/value pairs, values
    # must conform to validation rules for options or exception will be raised
    def process_options(options)
      options.each do |key, value|
        key = key.to_s
        raise OptionError, "No Option #{key}" unless self.class.options[key]

        opt = send(key.to_s)
        opt.value = value
        raise OptionError, "Bad value for option #{key}" unless opt.valid?
      end
      validate_required_options
    end

    def validate_required_options
      self.class.send('required_options').each do |name|
        opt = send(name.to_s)
        unless opt.valid?
          raise OptionError,
                "Required option #{name} missing or invalid"
        end
      end
    end

    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    private :validate_required_options
    protected :process_options

    # Class methods used by configurable classes
    module ClassMethods
      def setup_options
        class_variable_get('@@options')
        class_variable_get('@@required_options')
      rescue StandardError
        class_variable_set('@@options', {})
        class_variable_set('@@required_options', [])
      end

      def setup_option(name, type, required, verifier)
        define_method(name.to_s) do
          unless instance_variable_get("@#{name}")
            instance_variable_set("@#{name}",
                                  Option.new(name, type, verifier))
          end
          instance_variable_get("@#{name}")
        end

        class_variable_get('@@required_options') << name if
          required == :required
        class_variable_get('@@options')[name] = type
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

      # Notes that this class has the specified option
      #
      # @param [String, Symbol] name Name of this option
      # @param [Class] type Type required for this option - will be verified
      # @param [optional, :optional, :required] required Is this option
      # required to be set, or merely optional
      def attr_option(name, type, required = :optional, &verifier)
        name = name.to_s
        setup_options
        setup_option(name, type, required, verifier)
      end

      def attr_output(name, type)
        name = name.to_s
        setup_outputs
        setup_output(name, type)
      end

      # Returns required set of options
      # @return [Array<Option>] Required options for this class
      def required_options
        class_variable_get('@@required_options')
      end

      # Returns valid oset of options
      # @return [Hash<String,Class>] Available set of options, with expected
      # class for each.
      def options
        class_variable_get('@@options')
      end

      # Returns set of outputs that are set
      # @return [Hash<String,Class>]] Outputs that are set on trigger, with
      # types of each as values
      def outputs
        class_variable_get('@@outputs')
      end

      protected :attr_option, :attr_output
      private :setup_options, :setup_option, :setup_output, :setup_outputs
    end
  end

  # Used to store options - includes the expected type
  # the name, and the value.  Also includes validation logic
  # - the absence of validation logic in the value= operator is
  # intentional, as there may be cases where you can set an invalid
  # option value
  class Option
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

  class OptionError < StandardError
  end
end
# rubocop:enable Style/ClassVars
