# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/actions/fork_graph_action'

RSpec.describe CGE::ForkGraphAction do
  let(:command_graph) { instance_double('CGE::CommandGraph') }
  let(:fork_thread) { Thread.new { sleep(0.1) } }
  let(:action) { described_class.new('fork_action_id', 'test_fork_action', {}, nil) }

  before do
    allow(command_graph).to receive(:fork_and_execute).and_return(fork_thread)
  end

  describe '#invoke' do
    it 'forks the graph and logs the action' do
      # Set up command_graph through execute to simulate real usage
      action.execute({}, nil, command_graph)
      expect(command_graph).to receive(:fork_and_execute).with({}, nil)
      action.invoke
    end

    it 'handles variables and subgraph_id' do
      inputs = {
        'variables' => { 'key' => 'value' },
        'subgraph_id' => 'test_subgraph'
      }
      action.execute(inputs, nil, command_graph)
      expect(command_graph).to receive(:fork_and_execute).with({ 'key' => 'value' }, 'test_subgraph')
      action.invoke
    end
  end

  describe '#execute' do
    context 'with no inputs' do
      it 'forks the graph with default parameters' do
        expect(command_graph).to receive(:fork_and_execute).with({}, nil)
        next_command = double('NextCommand')
        result = action.execute({}, next_command, command_graph)
        expect(result).to eq(next_command)
      end
    end

    context 'with subgraph_id specified' do
      let(:inputs) { { 'subgraph_id' => 'alt_flow' } }

      it 'forks the graph with specified subgraph' do
        expect(command_graph).to receive(:fork_and_execute).with({}, 'alt_flow')
        next_command = double('NextCommand')
        result = action.execute(inputs, next_command, command_graph)
        expect(result).to eq(next_command)
      end
    end

    context 'with variables specified' do
      let(:variables) { { 'user_id' => '123', 'action' => 'process' } }
      let(:inputs) { { 'variables' => variables } }

      it 'forks the graph with specified variables' do
        expect(command_graph).to receive(:fork_and_execute).with(variables, nil)
        next_command = double('NextCommand')
        result = action.execute(inputs, next_command, command_graph)
        expect(result).to eq(next_command)
      end
    end

    context 'with both subgraph_id and variables' do
      let(:variables) { { 'task_id' => '456', 'priority' => 'high' } }
      let(:inputs) do
        { 
          'subgraph_id' => 'worker_flow',
          'variables' => variables
        }
      end

      it 'forks the graph with both parameters' do
        expect(command_graph).to receive(:fork_and_execute).with(variables, 'worker_flow')
        next_command = double('NextCommand')
        result = action.execute(inputs, next_command, command_graph)
        expect(result).to eq(next_command)
      end
    end

    context 'with empty variables hash' do
      let(:inputs) { { 'variables' => {} } }

      it 'forks the graph with empty variables' do
        expect(command_graph).to receive(:fork_and_execute).with({}, nil)
        next_command = double('NextCommand')
        result = action.execute(inputs, next_command, command_graph)
        expect(result).to eq(next_command)
      end
    end

    context 'with complex variables' do
      let(:complex_variables) do
        {
          'config' => { 'timeout' => 30, 'retries' => 3 },
          'data' => ['item1', 'item2', 'item3'],
          'metadata' => { 'source' => 'api', 'timestamp' => Time.now.to_i }
        }
      end
      let(:inputs) { { 'variables' => complex_variables } }

      it 'forks the graph with complex variables' do
        expect(command_graph).to receive(:fork_and_execute).with(complex_variables, nil)
        next_command = double('NextCommand')
        result = action.execute(inputs, next_command, command_graph)
        expect(result).to eq(next_command)
      end
    end
  end

  describe 'input validation' do
    it 'accepts valid subgraph_id input' do
      expect { 
        action.send(:process_inputs, { 'subgraph_id' => 'valid_subgraph' }) 
      }.not_to raise_error
    end

    it 'accepts valid variables input' do
      expect { 
        action.send(:process_inputs, { 'variables' => { 'key' => 'value' } }) 
      }.not_to raise_error
    end

    it 'validates subgraph_id is a string when provided' do
      expect { 
        action.send(:process_inputs, { 'subgraph_id' => 123 }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates variables is a hash when provided' do
      expect { 
        action.send(:process_inputs, { 'variables' => 'not_a_hash' }) 
      }.to raise_error(CGE::InputError)
    end

    it 'handles nil subgraph_id gracefully' do
      expect { 
        action.send(:process_inputs, { 'subgraph_id' => nil }) 
      }.to raise_error(CGE::InputError)
    end

    it 'handles nil variables gracefully' do
      expect { 
        action.send(:process_inputs, { 'variables' => nil }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts empty inputs' do
      expect { 
        action.send(:process_inputs, {}) 
      }.not_to raise_error
    end

    it 'rejects empty string subgraph_id' do
      expect { 
        action.send(:process_inputs, { 'subgraph_id' => '' }) 
      }.to raise_error(CGE::InputError)
    end
  end

  describe 'error handling' do
    context 'when command_graph is nil' do
      it 'raises an error' do
        expect { 
          action.execute({}, nil, nil) 
        }.to raise_error(NoMethodError)
      end
    end

    context 'when fork_and_execute fails' do
      before do
        allow(command_graph).to receive(:fork_and_execute).and_raise(StandardError, 'Fork failed')
      end

      it 'propagates the error' do
        expect { 
          action.execute({}, nil, command_graph) 
        }.to raise_error(StandardError, 'Fork failed')
      end
    end

    context 'when fork_and_execute returns nil' do
      before do
        allow(command_graph).to receive(:fork_and_execute).and_return(nil)
      end

      it 'handles nil return value gracefully' do
        expect { 
          action.execute({}, nil, command_graph) 
        }.not_to raise_error
      end
    end
  end

  describe 'thread safety' do
    it 'handles concurrent executions' do
      threads = []
      results = []

      5.times do |i|
        threads << Thread.new do
          thread_action = described_class.new("fork_action_#{i}", 'test_fork_action', {}, nil)
          thread_graph = instance_double('CGE::CommandGraph')
          thread_thread = Thread.new { sleep(0.01) }
          allow(thread_graph).to receive(:fork_and_execute).and_return(thread_thread)
          
          result = thread_action.execute(
            { 'variables' => { 'thread_id' => i } },
            nil,
            thread_graph
          )
          results << result
        end
      end

      threads.each(&:join)
      expect(results.size).to eq(5)
    end
  end

  describe 'integration scenarios' do
    it 'works with unicode subgraph IDs' do
      unicode_subgraph = 'подграф_🌸_그래프'
      expect(command_graph).to receive(:fork_and_execute).with({}, unicode_subgraph)
      
      action.execute({ 'subgraph_id' => unicode_subgraph }, nil, command_graph)
    end

    it 'works with unicode variable keys and values' do
      unicode_variables = {
        'ключ_🔑' => 'значение_💎',
        '키_🗝️' => '값_💍'
      }
      expect(command_graph).to receive(:fork_and_execute).with(unicode_variables, nil)
      
      action.execute({ 'variables' => unicode_variables }, nil, command_graph)
    end

    it 'works with nested hash variables' do
      nested_variables = {
        'config' => {
          'database' => {
            'host' => 'localhost',
            'port' => 5432,
            'credentials' => {
              'username' => 'admin',
              'password' => 'secret'
            }
          }
        }
      }
      expect(command_graph).to receive(:fork_and_execute).with(nested_variables, nil)
      
      action.execute({ 'variables' => nested_variables }, nil, command_graph)
    end

    it 'works with array variables' do
      array_variables = {
        'items' => ['item1', 'item2', 'item3'],
        'numbers' => [1, 2, 3, 4, 5],
        'mixed' => ['string', 123, true, nil]
      }
      expect(command_graph).to receive(:fork_and_execute).with(array_variables, nil)
      
      action.execute({ 'variables' => array_variables }, nil, command_graph)
    end

    it 'works with boolean and numeric variables' do
      mixed_variables = {
        'is_enabled' => true,
        'count' => 42,
        'percentage' => 85.5,
        'disabled' => false
      }
      expect(command_graph).to receive(:fork_and_execute).with(mixed_variables, nil)
      
      action.execute({ 'variables' => mixed_variables }, nil, command_graph)
    end
  end

  describe 'edge cases' do

    it 'handles very long subgraph_id' do
      long_subgraph = 'a' * 1000
      expect(command_graph).to receive(:fork_and_execute).with({}, long_subgraph)
      action.execute({ 'subgraph_id' => long_subgraph }, nil, command_graph)
    end

    it 'handles large variable sets' do
      large_variables = {}
      100.times { |i| large_variables["key_#{i}"] = "value_#{i}" }
      
      expect(command_graph).to receive(:fork_and_execute).with(large_variables, nil)
      action.execute({ 'variables' => large_variables }, nil, command_graph)
    end

    it 'handles variables with special characters in keys' do
      special_variables = {
        'key-with-dashes' => 'value1',
        'key_with_underscores' => 'value2',
        'key.with.dots' => 'value3',
        'key@with@symbols' => 'value4'
      }
      expect(command_graph).to receive(:fork_and_execute).with(special_variables, nil)
      
      action.execute({ 'variables' => special_variables }, nil, command_graph)
    end
  end
end