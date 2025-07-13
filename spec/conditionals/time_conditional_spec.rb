# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/conditionals/time_conditional'

RSpec.describe CGE::TimeConditional do
  let(:conditional) { described_class.new('time_id', 'test_time', {}, nil, nil, nil) }
  let(:next_command) { double('NextCommand') }

  describe '#determine_next_node' do
    context 'with after operation (default)' do
      it 'returns next_command when current time is after specified time' do
        past_time = (Time.now - 3600).strftime('%Y-%m-%d %H:%M:%S') # 1 hour ago
        conditional.send(:process_inputs, { 'time' => past_time })
        
        mock_graph = double('CommandGraph')
        result = conditional.send(:determine_next_node, next_command, mock_graph)
        expect(result).to eq(next_command)
      end

      it 'returns nil when current time is before specified time' do
        future_time = (Time.now + 3600).strftime('%Y-%m-%d %H:%M:%S') # 1 hour from now
        conditional.send(:process_inputs, { 'time' => future_time })
        
        mock_graph = double('CommandGraph')
        result = conditional.send(:determine_next_node, next_command, mock_graph)
        expect(result).to be_nil
      end
    end

    context 'with before operation' do
      it 'returns next_command when current time is before specified time' do
        future_time = (Time.now + 3600).strftime('%Y-%m-%d %H:%M:%S') # 1 hour from now
        conditional.send(:process_inputs, { 
          'time' => future_time,
          'operator' => 'before'
        })
        
        mock_graph = double('CommandGraph')
        result = conditional.send(:determine_next_node, next_command, mock_graph)
        expect(result).to eq(next_command)
      end

      it 'returns nil when current time is after specified time' do
        past_time = (Time.now - 3600).strftime('%Y-%m-%d %H:%M:%S') # 1 hour ago
        conditional.send(:process_inputs, { 
          'time' => past_time,
          'operator' => 'before'
        })
        
        mock_graph = double('CommandGraph')
        result = conditional.send(:determine_next_node, next_command, mock_graph)
        expect(result).to be_nil
      end
    end

    context 'with equal operation' do
      it 'returns next_command when times are within tolerance' do
        now_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        conditional.send(:process_inputs, { 
          'time' => now_time,
          'operator' => 'equal',
          'tolerance' => 120
        })
        
        mock_graph = double('CommandGraph')
        result = conditional.send(:determine_next_node, next_command, mock_graph)
        expect(result).to eq(next_command)
      end

      it 'returns nil when times are outside tolerance' do
        far_past = (Time.now - 7200).strftime('%Y-%m-%d %H:%M:%S') # 2 hours ago
        conditional.send(:process_inputs, { 
          'time' => far_past,
          'operator' => 'equal',
          'tolerance' => 60
        })
        
        mock_graph = double('CommandGraph')
        result = conditional.send(:determine_next_node, next_command, mock_graph)
        expect(result).to be_nil
      end
    end
  end

  describe 'input validation' do
    it 'requires time input' do
      expect { conditional.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input time/)
    end

    it 'validates time is not empty' do
      expect { 
        conditional.send(:process_inputs, { 'time' => '' }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates operator is valid' do
      expect { 
        conditional.send(:process_inputs, { 
          'time' => 'now', 
          'operator' => 'invalid' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates tolerance is non-negative' do
      expect { 
        conditional.send(:process_inputs, { 
          'time' => 'now', 
          'tolerance' => -5 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs' do
      expect { 
        conditional.send(:process_inputs, { 
          'time' => 'now',
          'operator' => 'equal',
          'tolerance' => 60
        }) 
      }.not_to raise_error
    end
  end
end