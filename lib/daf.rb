require 'daf/command'
require 'daf/datasources/yaml_command_graph'
require 'daf/datasources/json_command_graph'
require 'daf/global_configuration'

# Starts the DAF daemon (DAD) - takes a directory
# containing the YAML and JSON files for monitor/action pairs
# After parsing configuration, will daemonize and continue
# monitoring until SIGTERM is received
#
# @author Kayla McArthur (mailto:kayla@kayla.is)
# @icense MIT License
module DAF
  def start_dad
    if ARGV[0] && File.directory?(ARGV[0])
      global_config = parse_global_config(ARGV[1])
      command_graphs = Dir["#{ARGV[0]}/*.yaml"].map do |file|
        YAMLCommandGraph.new(file)
      end

      Dir["#{ARGV[0]}/*.json"].each do |file|
        command_graphs << JSONCommandGraph.new(file)
      end

      dad = DynamicActionDaemon.new(command_graphs, global_config)
      dad.start
    else
      print_usage
    end
  end

  def parse_global_config(config_path)
    return nil unless config_path && File.file?(config_path)

    GlobalConfiguration.new(config_path)
  end

  def print_usage
    puts 'DAF not started - please see below'
    puts 'Usage: daf [path to config folder] [optional: path to global config file]'
    puts 'Directory must contain one or more config'
    puts 'files with a .yaml or .json extension'
    puts 'Global config file must be .yaml, .yml, or .json'
  end

  # This class represents the Dynamic Action Daemon
  # it requires a set of commands to be passed in
  class DynamicActionDaemon
    # Initializes DAD with a given command set
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
