require 'spec_helper'

# Mock out process
module Process
  # Mock out status
  class Status
    attr_accessor :exitstatus
  end
end

# Mock out kernel
module Kernel
  def `(other)
    "result: #{other}"
  end
end

describe DAF::ShellAction do
  before(:each) do
    @options = { 'path' => '/bin/ls' }
    @action = DAF::ShellAction.new
  end

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

  it 'has an output results of type String' do
    expect { @action.class.outputs }.not_to raise_error
    expect(@action.class.outputs.length).to eq(1)
    expect(@action.class.outputs['results']).to eq(String)
  end

  it 'executes a shell script and saves as output' do
    @action.activate(@options)
    expect(@action.results).to eq('result: /bin/ls')
  end

  it 'passes arguments to shell script' do
    @options['arguments'] = 'test'
    @action.activate(@options)
    expect(@action.results).to eq('result: /bin/ls test')
  end

  it 'returns exist status of shell script' do
    $CHILD_STATUS.exitstatus = false
    expect(@action.activate(@options)).to eq(false)
    $CHILD_STATUS.exitstatus = true
    expect(@action.activate(@options)).to eq(true)
  end
end
