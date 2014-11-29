require_relative "../Monitor.rb"

class FileUpdateMonitor < Monitor
  has_option "path", String
  has_option "frequency", Integer

  def initialize(*options)
    super 
  end

end
