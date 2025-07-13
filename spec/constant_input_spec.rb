require 'spec_helper'

describe CGE::ConstantInput do
  let(:constant_input) { CGE::ConstantInput.new('constant_input_id', 'constant_input', {}, nil) }
  let(:inputs) { { 'constant' => 'hello world' } }

  it 'should inherit from Input' do
    expect(constant_input).to be_a(CGE::Input)
  end

  it 'should have a constant input' do
    expect(constant_input.class.inputs).to have_key('constant')
    expect(constant_input.class.inputs['constant']).to eq(String)
  end

  it 'should have an output input' do
    expect(constant_input.class.outputs).to have_key('output')
    expect(constant_input.class.outputs['output']).to eq(String)
  end

  it 'should require the constant input' do
    expect(constant_input.class.required_inputs).to include('constant')
  end

  it 'should set the output to the constant value when processed' do
    mock_graph = double('CommandGraph')
    constant_input.execute(inputs, nil, mock_graph)
    expect(constant_input.output).to eq('hello world')
  end

  it 'should raise an error when constant is not provided' do
    mock_graph = double('CommandGraph')
    expect { constant_input.execute({}, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Required input constant missing/)
  end

  it 'should raise an error when constant is not a string' do
    mock_graph = double('CommandGraph')
    expect { constant_input.execute({ 'constant' => 123 }, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input constant/)
  end
end