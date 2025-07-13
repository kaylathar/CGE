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
  let(:test_input) { TestInput.new('test_input_id', 'test_input', {}, nil) }
  let(:inputs) { { 'input' => 'test' } }

  it 'should set input values' do
    mock_graph = double('CommandGraph')
    test_input.execute(inputs, nil, mock_graph)
    expect(test_input.input.value).to eq('test')
  end
end