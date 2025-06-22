require 'cge/input'

module CGE
  # A simple input that propagates a constant string to the graph
  class ConstantInput < Input
    attr_option 'constant', String, :required
    attr_output 'output', String

    protected

    def invoke
      @output = constant.value
    end
  end
end
