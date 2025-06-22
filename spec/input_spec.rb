require 'spec_helper'

# Test input to verify functionality
class TestInput < CGE::Input
  attr_accessor :result
  def invoke
    @output = @result
  end
  attr_input :input, String
  attr_output :output, String
end

describe CGE::Input do
  let(:test_input) { TestInput.new('test_input', {}) }
  let(:inputs) { { 'input' => 'test' } }

  it 'should set input values' do
    test_input.execute(inputs, nil)
    expect(test_input.input.value).to eq('test')
  end
end