require 'spec_helper'

describe DAF::Configurable do
  # Test class to verify Configurable functionality
  class MockClass
    include DAF::Configurable

    attr_option :test, String, :required
    attr_option :test2, Integer, :optional do |val|
      val > 2
    end

    attr_output :test_out, String
    attr_output :test2_out, Integer
  end

  before(:each) do
    @under_test = MockClass.new
  end

  it 'has required option' do
    expect { MockClass.required_options }.to_not raise_error
    expect(MockClass.required_options).not_to be_empty
    expect(MockClass.required_options.length).to eq(1)
  end

  it 'has options' do
    expect { MockClass.options }.to_not raise_error
    expect(MockClass.options).not_to be_empty
    expect(MockClass.options.length).to eq(2)
  end

  it 'has outputs' do
    expect { MockClass.outputs }.to_not raise_error
    expect(MockClass.outputs).not_to be_empty
    expect(MockClass.outputs.length).to eq(2)
  end

  it 'has readable outputs' do
    expect { @under_test.test2_out }.to_not raise_error
    expect { @under_test.test_out }.to_not raise_error
  end

  it 'exposes required type for inputs' do
    expect(@under_test.test.type).to eq(String)
    expect(@under_test.test2.type).to eq(Integer)
  end

  it 'has writable inputs' do
    @under_test.test.value = 'Test'
    @under_test.test2.value = 40
    expect(@under_test.test.value).to eq('Test')
    expect(@under_test.test2.value).to eq(40)
  end

  it 'validates inputs' do
    @under_test.test.value = 40
    @under_test.test2.value = 'bad value'
    expect(@under_test.test.valid?).to eq(false)
    expect(@under_test.test.valid?).to eq(false)
  end
end
