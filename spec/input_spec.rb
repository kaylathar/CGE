require 'spec_helper'

# Test input to verify functionality
class TestInput < DAF::Input
  attr_accessor :result
  def invoke
    @output = @result
  end
  attr_option :option, String
  attr_output :output, String
end

describe DAF::Input do
  let(:test_input) { TestInput.new }
  let(:options) { { 'option' => 'test' } }

  it 'should set option values' do
    test_input.process(options)
    expect(test_input.option.value).to eq('test')
  end
end