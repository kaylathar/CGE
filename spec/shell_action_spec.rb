require 'spec_helper'

describe DAF::ShellAction do
  before(:each) do
    @options = { 'path' => '/bin/ls' }
    @action = DAF::ShellAction.new("test_action", {})
  end

  context 'options' do
    it 'has a required path option of type String' do
      expect { @action.class.required_options }.not_to raise_error
      expect(@action.class.required_options.length).to eq(1)
    end

    it 'validates the path is executable and exists' do
      @action.path.value = '/bin/ls'
      expect(@action.path.valid?).to eq(true)
      @action.path.value = '/tmp/nonsense'
      expect(@action.path.valid?).to eq(false)
      @action.path.value = '/tmp/test1'
      expect(@action.path.valid?).to eq(false)
    end

    it 'has an optional arguments option of type String' do
      expect { @action.class.options }.not_to raise_error
      expect(@action.class.options.length).to eq(2)
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
      @action.execute(@options, nil)
    end

    it 'returns the result of shell script' do
      allow(@action).to receive(:`).and_return('result!')
      @action.execute(@options, nil)
      expect(@action.results).to eq('result!')
    end

    it 'passes arguments to the shell script' do
      expect(@action).to receive(:`).with('/bin/ls test')
      @options['arguments'] = 'test'
      @action.execute(@options, nil)
    end
  end
end
