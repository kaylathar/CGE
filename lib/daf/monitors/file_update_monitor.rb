require 'daf/monitor'

module DAF
  # Monitor that watches a file's last update time, and triggers when it changes
  # includes several return outputs that can be used as well
  class FileUpdateMonitor < Monitor
    attr_option :path, String, :required do |val|
      File.exist? val
    end

    attr_option :frequency, Integer, :required do |val|
      val >= 1
    end

    # @return [Time] The last modified time of file that caused trigger
    attr_output :time, Time

    # @return [String] The contents of the tile that caused trigger
    attr_output :contents, String

    def block_until_triggered
      initial_modified_time = File.mtime(@path.value)
      loop do
        sleep @frequency.value
        modified_time = File.mtime(@path.value)
        next unless modified_time > initial_modified_time

        @time = modified_time
        @contents = contents_of_file(@path.value)
        break
      end
    end

    def contents_of_file(path)
      file = File.open(path)
      contents = file.read
      file.close
      contents
    end

    private :contents_of_file
  end
end
