require 'cge/input'

module CGE
  # An input that reads the contents of a file at a given path
  class FileInput < Input
    attr_input 'file_path', String, :required do |val|
      File.file?(val) && File.readable?(val)
    end
    attr_output 'content', String

    def invoke
      @content = File.read(file_path.value)
    rescue StandardError => e
      raise FileInputError, "Failed to read file: #{e.message}"
    end
  end

  class FileInputError < StandardError
  end
end
CGE::Command.register_command(CGE::FileInput)
