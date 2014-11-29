require_relative "../Monitor.rb"

class FileUpdateMonitor < Monitor
  has_option "path", String do |val|
    File.exist? val 
  end
  
  has_option "frequency", Integer do |val|
    val > 1 
  end

  def initialize(*options)
    super 
  end

  def block_until_triggered
    initialModifiedTime = File.mtime(@path)
    modifiedTime = File.mtime(@path) 
    until modifiedTime > initialModifiedTime
      sleep @frequency
      modifiedTime = File.mtime(@path)
    end
  end

end
