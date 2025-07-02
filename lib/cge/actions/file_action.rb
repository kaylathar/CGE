# frozen_string_literal: true

require 'fileutils'

module CGE
  # An action to write to a local file
  class FileAction < Action
    attr_input :path, String, :required
    attr_input :content, String, :required
    attr_input :create_directories, Object

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
CGE::Command.register_command(CGE::FileAction)
