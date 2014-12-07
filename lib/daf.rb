require 'daf/datasources/yaml_data_source'

# Starts the DAF daemon (DAD) - takes a directory
# containing the YAML files for monitor/action pairs
# After parsing configuration, will daemonize and continue
# monitoring until SIGTERM is received
#
# Author::    Kayla McArthur (mailto:kayla@kayla.is)
# Copyright:: Copyright (c) 2014 Kayla McArthur
# License::   MIT License

def start_dad
  if ARGV[0] && File.directory?(ARGV[0])
    commands = []

    Dir[ARGV[0] + '/*.yaml'].each do |file|
      commands << Command.new(YAMLDataSource.new(file))
    end

    dad = DynamicActionDaemon.new(commands)
    dad.start
  else
    print_usage
  end
end

def print_usage
  puts 'DAF not started - please see below'
  puts 'Usage: daf [path to config folder]'
  puts 'Directory must contain one or more config'
  puts 'files with a .yaml extension'
end

# This class represents the Dynamic Action Daemon
# it requires a set of commands to be passed in
class DynamicActionDaemon
  # Initializes DAD with a given command set
  #
  # @param commands [Array] Array containing Command objects
  def initialize(commands)
    @commands = commands
  end

  # Starts the daemon - this method will block for duration
  # of execution of program
  def start
    @commands.each(&:execute)
    sleep
  end
end

start_dad if __FILE__ == $PROGRAM_NAME
