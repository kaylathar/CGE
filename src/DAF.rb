require_relative 'Command'


def start_dad
  if ARGV[0] && File.directory?(ARGV[0])
    dad = DynamicActionDaemon.new(ARGV[0])
    dad.start()
  else
    print_usage
  end 
    
end

def print_usage
  puts "DAF not started - please see below"
  puts "Usage: daf [path to config folder]"
  puts "Directory must contain one or more config"
  puts "files with a .yaml extension"
end


class DynamicActionDaemon
  def initialize(configPath)
    @commands = []
    Dir[configPath + "/*.yaml"].each do |file|
      @commands << Command.new(file)
    end 
  end

  def start
    @commands.each do |command|
      command.execute()
      sleep
    end
  end
end


start_dad() if __FILE__ == $0
