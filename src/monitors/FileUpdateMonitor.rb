require_relative "../Monitor.rb"

class FileUpdateMonitor < Monitor
  has_option "path", String, :required do |val|
    File.exist? val 
  end
  
  has_option "frequency", Integer, :required do |val|
    val > 1 
  end

  has_output "time", Time
  has_output "contents", String

  def initialize(options)
    super 
  end

  def block_until_triggered
    initialModifiedTime = File.mtime(@path.value)
    loop do
      sleep @frequency.value
      modifiedTime = File.mtime(@path.value)
      if modifiedTime > initialModifiedTime
        @time = modifiedTime
        file = File.open(@path.value)
        @contents = file.read()
        file.close()
        break
      end
    end
  end

end
