# frozen_string_literal: true

require 'cge/command'
require 'cge/graphs/yaml_command_graph'
require 'cge/graphs/json_command_graph'
require 'cge/global_configuration'
require 'cge/service_manager'
require 'cge/logging'

# Starts the CGE daemon (CGD) - takes a directory
# containing the YAML and JSON files for monitor/action pairs
# After parsing configuration, will daemonize and continue
# monitoring until SIGTERM is received
#
# @author Kayla McArthur (mailto:kayla@kayla.is)
# @license MIT License
module CGE
  def self.log_level
    @@log_level || CGE::Logging::LOG_LEVEL_NONE
  end

  def start_cgd
    if ARGV[0] && File.directory?(ARGV[0])
      service_manager = ServiceManager.new
      global_config = parse_global_config(ARGV[1])
      command_graphs = Dir["#{ARGV[0]}/*.yaml"].map do |file|
        YAMLCommandGraph.from_file(file, global_config, service_manager)
      end

      Dir["#{ARGV[0]}/*.json"].each do |file|
        command_graphs << JSONCommandGraph.from_file(file, global_config, service_manager)
      end

      @@log_level = global_config.log_level

      cgd = CommandGraphExecutor.new(command_graphs, global_config)
      cgd.start
    else
      print_usage
    end
  end

  def parse_global_config(config_path)
    return nil unless config_path && File.file?(config_path)

    GlobalConfiguration.new(config_path)
  end

  def print_usage
    puts 'CGE not started - please see below'
    puts 'Usage: cge [path to config folder] [optional: path to global config file]'
    puts 'Directory must contain one or more config'
    puts 'files with a .yaml or .json extension'
    puts 'Global config file must be .yaml, .yml, or .json'
  end

  # This class represents the Command Graph Executor
  # it requires a set of commands to be passed in
  class CommandGraphExecutor
    # Initializes CGD with a given command set
    #
    # @param commands [Array] Array containing Command objects
    # @param global_config [GlobalConfiguration, nil] Optional global configuration
    def initialize(commands, global_config)
      @commands = commands
      @global_config = global_config
    end

    # Starts the daemon - this method will block for duration
    # of execution of program
    def start
      @commands.each(&:execute)
      sleep
    end
  end
end
