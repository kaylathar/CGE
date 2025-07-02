# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/conditionals/inclusion_conditional'

RSpec.describe CGE::InclusionConditional do
  let(:conditional) { described_class.new('include_id', 'test_include', {}, nil, nil, nil) }
  let(:next_command) { double('NextCommand') }

  describe '#determine_next_node' do
    context 'with include operation (default)' do
      it 'returns next_command when value is in set' do
        conditional.send(:process_inputs, {
          'value' => 'apple',
          'set' => 'apple,banana,cherry'
        })
        
        result = conditional.send(:determine_next_node, next_command)
        expect(result).to eq(next_command)
      end

      it 'returns nil when value is not in set' do
        conditional.send(:process_inputs, {
          'value' => 'grape',
          'set' => 'apple,banana,cherry'
        })
        
        result = conditional.send(:determine_next_node, next_command)
        expect(result).to be_nil
      end
    end

    context 'with exclude operation' do
      it 'returns next_command when value is not in set' do
        conditional.send(:process_inputs, {
          'value' => 'grape',
          'set' => 'apple,banana,cherry',
          'operation' => 'exclude'
        })
        
        result = conditional.send(:determine_next_node, next_command)
        expect(result).to eq(next_command)
      end

      it 'returns nil when value is in set' do
        conditional.send(:process_inputs, {
          'value' => 'apple',
          'set' => 'apple,banana,cherry',
          'operation' => 'exclude'
        })
        
        result = conditional.send(:determine_next_node, next_command)
        expect(result).to be_nil
      end
    end

    context 'with case sensitivity' do
      it 'performs case-sensitive matching by default' do
        conditional.send(:process_inputs, {
          'value' => 'Apple',
          'set' => 'apple,banana,cherry',
          'case_sensitive' => true
        })
        
        result = conditional.send(:determine_next_node, next_command)
        expect(result).to be_nil
      end

      it 'performs case-insensitive matching when disabled' do
        conditional.send(:process_inputs, {
          'value' => 'Apple',
          'set' => 'apple,banana,cherry',
          'case_sensitive' => false
        })
        
        result = conditional.send(:determine_next_node, next_command)
        expect(result).to eq(next_command)
      end
    end

    context 'with whitespace in set' do
      it 'strips whitespace from set values' do
        conditional.send(:process_inputs, {
          'value' => 'apple',
          'set' => ' apple , banana , cherry '
        })
        
        result = conditional.send(:determine_next_node, next_command)
        expect(result).to eq(next_command)
      end
    end
  end

  describe 'input validation' do
    it 'requires value input' do
      expect { conditional.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input value/)
    end

    it 'requires set input' do
      expect { 
        conditional.send(:process_inputs, { 'value' => 'test' }) 
      }.to raise_error(CGE::InputError, /Required input set/)
    end

    it 'validates set is not empty' do
      expect { 
        conditional.send(:process_inputs, { 
          'value' => 'test', 
          'set' => '' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates operation is valid' do
      expect { 
        conditional.send(:process_inputs, { 
          'value' => 'test', 
          'set' => 'a,b,c',
          'operation' => 'invalid'
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs' do
      expect { 
        conditional.send(:process_inputs, { 
          'value' => 'test', 
          'set' => 'test,other',
          'operation' => 'include',
          'case_sensitive' => true
        }) 
      }.not_to raise_error
    end
  end

  describe '#execute' do
    it 'processes inputs and returns appropriate result' do
      inputs = {
        'value' => 'apple',
        'set' => 'apple,banana,cherry'
      }
      
      result = conditional.execute(inputs, next_command)
      expect(result).to eq(next_command)
    end
  end
end