require 'spec_helper'

describe CGE::ShellAction do
  before(:each) do
    @inputs = { 'path' => '/bin/ls' }
    @action = CGE::ShellAction.new('shell_action_id', "test_action", {}, nil)
  end

  context 'inputs' do
    it 'has a required path input of type String' do
      expect { @action.class.required_inputs }.not_to raise_error
      expect(@action.class.required_inputs.length).to eq(1)
    end

    it 'validates the path is executable and exists' do
      @action.path.value = '/bin/ls'
      expect(@action.path.valid?).to eq(true)
      @action.path.value = '/tmp/nonsense'
      expect(@action.path.valid?).to eq(false)
      @action.path.value = '/tmp/test1'
      expect(@action.path.valid?).to eq(false)
    end

    it 'has an optional arguments input of type String' do
      expect { @action.class.inputs }.not_to raise_error
      expect(@action.class.inputs.length).to eq(2)
    end
  end

  it 'has an output results of type String' do
    expect { @action.class.outputs }.not_to raise_error
    expect(@action.class.outputs.length).to eq(1)
    expect(@action.class.outputs['results']).to eq(String)
  end

  context 'when execute is called' do
    it 'executes a shell script' do
      expect(@action).to receive(:`).with('/bin/ls')
      @action.execute(@inputs, nil)
    end

    it 'returns the result of shell script' do
      allow(@action).to receive(:`).and_return('result!')
      @action.execute(@inputs, nil)
      expect(@action.results).to eq('result!')
    end

    it 'passes arguments to the shell script' do
      expect(@action).to receive(:`).with('/bin/ls test')
      @inputs['arguments'] = 'test'
      @action.execute(@inputs, nil)
    end
  end
end
