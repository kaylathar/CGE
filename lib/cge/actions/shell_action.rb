# frozen_string_literal: true

require 'cge/action'
require 'English'

module CGE
  # An action that executes a shell script
  class ShellAction < Action
    attr_input :path, String, :required do |value|
      File.executable?(value)
    end

    attr_input :arguments, String

    attr_output :results, String

    def invoke
      arguments = self.arguments.value ? " #{self.arguments.value}" : ''
      @results = `#{path.value}#{arguments}`
      $CHILD_STATUS.exitstatus
    end
  end
end
CGE::Command.register_command(CGE::ShellAction)
