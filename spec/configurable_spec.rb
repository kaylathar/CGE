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
    expect(MockClass.required_options).not_to be_empty
  end
end
