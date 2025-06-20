require 'spec_helper'

describe DAF::ConstantInput do
  let(:constant_input) { DAF::ConstantInput.new }
  let(:options) { { 'constant' => 'hello world' } }

  it 'should inherit from Input' do
    expect(constant_input).to be_a(DAF::Input)
  end

  it 'should have a constant option' do
    expect(constant_input.class.options).to have_key('constant')
    expect(constant_input.class.options['constant']).to eq(String)
  end

  it 'should have an output option' do
    expect(constant_input.class.outputs).to have_key('output')
    expect(constant_input.class.outputs['output']).to eq(String)
  end

  it 'should require the constant option' do
    expect(constant_input.class.required_options).to include('constant')
  end

  it 'should set the output to the constant value when processed' do
    constant_input.process(options)
    expect(constant_input.output).to eq('hello world')
  end

  it 'should raise an error when constant is not provided' do
    expect { constant_input.process({}) }
      .to raise_error(DAF::OptionError, /Required option constant missing/)
  end

  it 'should raise an error when constant is not a string' do
    expect { constant_input.process({ 'constant' => 123 }) }
      .to raise_error(DAF::OptionError, /Bad value for option constant/)
  end
end