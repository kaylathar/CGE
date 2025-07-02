# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/monitors/wait_monitor'

RSpec.describe CGE::WaitMonitor do
  let(:monitor) { described_class.new('wait_id', 'test_wait', {}, nil, nil, nil) }

  describe '#block_until_triggered' do
    it 'waits for the specified duration in seconds' do
      monitor.send(:process_inputs, { 'duration' => 1 })
      
      start_time = Time.now
      monitor.block_until_triggered
      end_time = Time.now
      
      elapsed = end_time - start_time
      expect(elapsed).to be_within(0.1).of(1.0)
    end
  end

  describe 'input validation' do
    it 'requires duration input' do
      expect { monitor.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input duration/)
    end

    it 'validates duration is positive' do
      expect { 
        monitor.send(:process_inputs, { 'duration' => 0 }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates duration is positive for negative values' do
      expect { 
        monitor.send(:process_inputs, { 'duration' => -5 }) 
      }.to raise_error(CGE::InputError)
    end
  end
end