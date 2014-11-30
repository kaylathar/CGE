require_relative "../Monitor.rb"

class FileUpdateMonitor < Monitor
  has_option "path", String do |val|
    File.exist? val 
  end
  
  has_option "frequency", Integer do |val|
    val > 1 
  end

  def initialize(options)
    super 
  end

  def block_until_triggered
    initialModifiedTime = File.mtime(@path.value)
    loop do
      sleep @frequency.value
      modifiedTime = File.mtime(@path.value)
      break if modifiedTime > initialModifiedTime
    end
  end

end
