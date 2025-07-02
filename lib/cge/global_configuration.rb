# frozen_string_literal: true

require 'yaml'
require 'json'
require 'cge/logging'

module CGE
  # Global configuration system for CGE daemon
  # Supports YAML and JSON configuration files with dedicated accessor methods
  #
  # Configuration file structure:
  #   heartbeat: 60
  #
  # @example
  #   config = GlobalConfiguration.new("/path/to/config.yml")
  #   config.heartbeat # => 60
  class GlobalConfiguration
    # Known configuration options with their defaults and validators
    KNOWN_OPTIONS = {
      heartbeat: {
        default: 60,
        visible: true,
        validator: ->(value) { value.is_a?(Integer) && value.positive? }
      },
      additional_plugins: {
        default: [],
        visible: false,
        validator: ->(value) { value.is_a?(Array) && value.all? { |path| path.is_a?(String) } }
      },
      log_level: {
        default: CGE::Logging::LOG_LEVEL_NONE,
        visible: false,
        validator: ->(value) { value.between?(CGE::Logging::LOG_LEVEL_DEBUG, CGE::Logging::LOG_LEVEL_ERROR) }
      }
    }.freeze

    # @param file_path [String] Path to YAML or JSON configuration file
    def initialize(file_path = nil)
      @config = {}

      # Set defaults
      KNOWN_OPTIONS.each do |key, options|
        @config[key] = options[:default]
      end

      return unless file_path

      configuration = parse_configuration_file(file_path)
      raise GlobalConfigurationError('Failed to parse configuration file') unless configuration

      load_configuration(configuration)
    end

    # Heartbeat interval in seconds
    # @return [Integer] Heartbeat interval (default: 60)
    def heartbeat
      @config[:heartbeat]
    end

    def log_level
      @config[:log_level]
    end

    # Additional plugin paths to load
    # @return [Array<String>] Array of plugin paths (default: [])
    def additional_plugins
      @config[:additional_plugins]
    end

    # Provides set of key/value pairs that should be visible to
    # the command graphs
    def command_visible_configs
      @config.filter do |key, _value|
        KNOWN_OPTIONS[key][:visible]
      end
    end

    # Load configuration from parsed hash
    # @param configuration [Hash] Parsed configuration data
    def load_configuration(configuration)
      configuration.each do |key, value|
        key_sym = key.to_sym
        if KNOWN_OPTIONS.key?(key_sym)
          validate_option(key_sym, value)
          @config[key_sym] = value
        else
          warn "Unknown configuration option '#{key}' ignored"
        end
      end
    end

    # Validate a configuration option
    # @param key [Symbol] Configuration key
    # @param value [Object] Configuration value
    def validate_option(key, value)
      validator = KNOWN_OPTIONS[key][:validator]
      return if validator.call(value)

      raise GlobalConfigurationError, "Invalid value for #{key}: #{value.inspect}"
    end

    # Parses configuration file based on extension
    # @param file_path [String] Path to configuration file
    # @return [Hash] Parsed configuration data
    # @raise [GlobalConfigurationError] If file format is unsupported or parsing fails
    def parse_configuration_file(file_path)
      case File.extname(file_path).downcase
      when '.yml', '.yaml'
        YAML.load_file(file_path)
      when '.json'
        JSON.parse(File.read(file_path))
      else
        raise GlobalConfigurationError,
              'Unsupported configuration file format. Use .yml, .yaml, or .json'
      end
    rescue StandardError => e
      raise GlobalConfigurationError, "Failed to parse configuration file: #{e.message}"
    end

    private :parse_configuration_file, :validate_option, :load_configuration
  end

  class GlobalConfigurationError < StandardError
  end
end
