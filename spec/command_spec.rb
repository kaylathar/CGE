require 'spec_helper'

describe DAF::Command do
  let(:datasource) do
    datasource = double('DAF::CommandDataSource')
    allow(datasource).to receive(:monitor).and_return(monitor)
    allow(datasource).to receive(:action).and_return(action)
    allow(datasource).to receive(:action_options).and_return({})
    datasource
  end
  let(:monitor)  { double('DAF::Monitor') }
  let(:action) { double('DAF::Action') }

  context 'when initialize is called' do
    it 'should accept a datasource' do
      expect { DAF::Command.new(datasource) }.to_not raise_error
    end
  end

  context 'when execute is called' do
    before(:each) do
      allow(action).to receive(:activate)
      allow(monitor).to receive(:on_trigger).and_yield
    end

    let(:ithread) do
      ithread = double('Thread')
      allow(ithread).to receive(:kill)
    end

    let(:thread) do
      thread = class_double('Thread').as_stubbed_const(
        transfer_nested_constants: true)
      allow(thread).to receive(:new).and_yield.and_return(ithread)
      allow(thread).to receive(:kill)
      allow(thread).to receive(:current).and_return(ithread)
      allow(thread).to receive(:main).and_return(ithread)
      thread
    end

    let(:command) do
      DAF::Command.new(datasource)
    end

    it 'should create a new thread' do
      expect(thread).to receive(:new)
      command.execute
    end

    it 'should terminate the thread when cancel called' do
      thread
      expect(ithread).to receive(:kill)
      command.execute
      command.cancel
    end

    it 'should trigger on data source monitor' do
      expect(monitor).to receive(:on_trigger).and_yield
      command.execute
      sleep(1)
      command.cancel
    end

    it 'should active data source action on trigger' do
      expect(action).to receive(:activate) # .with({})
      command.execute
      sleep(1)
      command.cancel
    end

    it 'should loop when action is complete' do
      expect(action).to receive(:activate).at_least(2).times
      command.execute
      sleep(1)
      command.cancel
    end
  end
end
