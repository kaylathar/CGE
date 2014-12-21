require 'spec_helper'

# Test action to verify functionality
class TestAction < DAF::Action
  attr_accessor :success
  alias_method :invoke, :success
  attr_option :option, String
end

describe DAF::Action do
  let(:test_action) { TestAction.new }
  let(:options) { { 'option' => 'test' } }

  it 'should be configurable' do
    mixed_in = DAF::Action.ancestors.select { |o| o.class == Module }
    expect(mixed_in).to include(DAF::Configurable)
  end

  it 'should have an activate method' do
    expect(test_action).to respond_to(:activate)
  end

  it 'should return whatever invoke returns' do
    test_action.success = 123
    expect(test_action.activate(options)).to eq(123)
  end

  it 'should yield to a given block with invoke return value' do
    test_action.success = 123
    expect { |b| test_action.activate(options, &b) }
      .to yield_with_args(123)
  end

  it 'should set option values' do
    test_action.activate(options)
    expect(test_action.option.value).to eq('test')
  end
end
