# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/inputs/time_input'

RSpec.describe CGE::TimeInput do
  let(:input) { described_class.new('time_id', 'test_time_input', {}, nil, nil, nil) }

  describe '#invoke' do
    before do
      input.send(:process_inputs, {})
      input.invoke
    end

    it 'sets iso_time output' do
      expect(input.iso_time).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'sets unix_timestamp output' do
      expect(input.unix_timestamp).to be_a(Integer)
      expect(input.unix_timestamp).to be > 0
    end

    it 'sets date output in YYYY-MM-DD format' do
      expect(input.date).to match(/\d{4}-\d{2}-\d{2}/)
    end

    it 'sets time_only output in HH:MM:SS format' do
      expect(input.time_only).to match(/\d{2}:\d{2}:\d{2}/)
    end

    it 'sets individual time components' do
      expect(input.year).to be_a(Integer)
      expect(input.month).to be_between(1, 12)
      expect(input.day).to be_between(1, 31)
      expect(input.hour).to be_between(0, 23)
      expect(input.minute).to be_between(0, 59)
      expect(input.second).to be_between(0, 59)
    end

    it 'sets formatted_time to iso8601 by default' do
      expect(input.formatted_time).to eq(input.iso_time)
    end
  end

  describe 'with different formats' do
    it 'formats time as unix timestamp' do
      input.send(:process_inputs, { 'format' => 'unix' })
      input.invoke
      
      expect(input.formatted_time).to match(/^\d+$/)
      expect(input.formatted_time.to_i).to eq(input.unix_timestamp)
    end

    it 'formats time as epoch timestamp' do
      input.send(:process_inputs, { 'format' => 'epoch' })
      input.invoke
      
      expect(input.formatted_time).to match(/^\d+$/)
      expect(input.formatted_time.to_i).to eq(input.unix_timestamp)
    end

    it 'formats time as RFC2822' do
      input.send(:process_inputs, { 'format' => 'rfc2822' })
      input.invoke
      
      # RFC2822 format example: "Mon, 01 Jan 2024 12:00:00 +0000"
      expect(input.formatted_time).to match(/\w{3}, \d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2}/)
    end

    it 'formats time with custom format' do
      input.send(:process_inputs, { 
        'format' => 'custom',
        'custom_format' => '%Y%m%d-%H%M%S'
      })
      input.invoke
      
      expect(input.formatted_time).to match(/\d{8}-\d{6}/)
    end

    it 'uses default custom format when none provided' do
      input.send(:process_inputs, { 'format' => 'custom' })
      input.invoke
      
      # Default custom format: '%Y-%m-%d %H:%M:%S'
      expect(input.formatted_time).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
    end
  end

  describe 'input validation' do
    it 'validates format is valid when provided' do
      expect { 
        input.send(:process_inputs, { 'format' => 'invalid_format' }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid formats' do
      %w[iso8601 unix epoch rfc2822 custom].each do |format|
        expect { 
          input.send(:process_inputs, { 'format' => format }) 
        }.not_to raise_error
      end
    end

    it 'accepts inputs without format (uses default)' do
      expect { 
        input.send(:process_inputs, {}) 
      }.not_to raise_error
    end
  end

  describe 'output attributes' do
    it 'responds to all output attributes' do
      expect(input).to respond_to(:iso_time)
      expect(input).to respond_to(:formatted_time)
      expect(input).to respond_to(:unix_timestamp)
      expect(input).to respond_to(:date)
      expect(input).to respond_to(:time_only)
      expect(input).to respond_to(:year)
      expect(input).to respond_to(:month)
      expect(input).to respond_to(:day)
      expect(input).to respond_to(:hour)
      expect(input).to respond_to(:minute)
      expect(input).to respond_to(:second)
    end
  end

  describe '#execute' do
    it 'processes inputs and invokes time gathering' do
      next_command = double('NextCommand')
      inputs = { 'format' => 'unix' }
      
      result = input.execute(inputs, next_command)
      
      expect(result).to eq(next_command)
      expect(input.formatted_time).to match(/^\d+$/)
    end
  end
end