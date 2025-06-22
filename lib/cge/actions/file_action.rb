require 'fileutils'

module CGE
  # An action to write to a local file
  class FileAction < Action
    attr_option :path, String, :required
    attr_option :content, String, :required
    attr_option :create_directories, Object

    def invoke
      FileUtils.mkdir_p(File.dirname(@path.value)) if !@create_directories.nil? && @create_directories.value
      File.write(@path.value, @content.value)
    rescue StandardError => e
      raise FileActionError, "Failed to write file: #{e.message}"
    end
  end

  class FileActionError < StandardError
  end
end
