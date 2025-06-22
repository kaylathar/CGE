require 'yaml'
require 'json'
require 'cge/configurable'

module CGE
  # Global configuration system for CGE daemon
  # Supports YAML and JSON configuration files with type validation
  #
  # Configuration file structure:
  #   heartbeat: 60
  #
  # @example
  #   config = GlobalConfiguration.new("/path/to/config.yml")
  #   config.heartbeat.value # => 60
  class GlobalConfiguration
    include Configurable

    attr_input :heartbeat, Integer, :optional do |value|
      value > 0
    end

    # @param file_path [String] Path to YAML or JSON configuration file
    def initialize(file_path = nil)
      return unless file_path

      configuration = parse_configuration_file(file_path)
      raise GlobalConfigurationError('Failed to parse configuration file') unless configuration

      process_inputs(configuration)
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

    private :parse_configuration_file
  end

  class GlobalConfigurationError < StandardError
  end
end
