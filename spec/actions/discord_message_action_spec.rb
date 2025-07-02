# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/actions/discord_message_action'

RSpec.describe CGE::DiscordMessageAction do
  let(:service_manager) { instance_double('CGE::ServiceManager') }
  let(:discord_service) { instance_double('CGE::DiscordService') }
  let(:discord_bot) { instance_double('CGE::DiscordBot') }
  let(:action) { described_class.new('action_id', 'test_action', {}, nil, nil, service_manager) }

  before do
    allow(service_manager).to receive(:lookup).with(:DiscordService).and_return(discord_service)
    allow(discord_service).to receive(:bot_for_token).and_return(discord_bot)
    allow(discord_bot).to receive(:running?).and_return(false)
    allow(discord_bot).to receive(:start)
    allow(discord_bot).to receive(:send_message).and_return(true)
  end

  describe '#invoke' do
    context 'with valid inputs' do
      before do
        action.send(:process_inputs, {
          'token' => 'test_discord_token',
          'destination' => '123456789',
          'message' => 'Hello, Discord!'
        })
      end

      it 'gets the bot from the Discord service' do
        expect(discord_service).to receive(:bot_for_token).with('test_discord_token')
        action.invoke
      end

      it 'starts the bot if not already running' do
        expect(discord_bot).to receive(:start)
        action.invoke
      end

      it 'does not start the bot if already running' do
        allow(discord_bot).to receive(:running?).and_return(true)
        expect(discord_bot).not_to receive(:start)
        action.invoke
      end

      it 'sends the message to the specified destination' do
        expect(discord_bot).to receive(:send_message).with('123456789', 'Hello, Discord!')
        action.invoke
      end

      it 'handles different destination types' do
        # Test with numeric destination
        action.send(:process_inputs, {
          'token' => 'test_token',
          'destination' => '987654321',
          'message' => 'Numeric destination'
        })
        
        expect(discord_bot).to receive(:send_message).with('987654321', 'Numeric destination')
        action.invoke
      end

      it 'handles message with special characters' do
        action.send(:process_inputs, {
          'token' => 'test_token',
          'destination' => '123456',
          'message' => 'Hello! @everyone 🎉 #general'
        })
        
        expect(discord_bot).to receive(:send_message).with('123456', 'Hello! @everyone 🎉 #general')
        action.invoke
      end

      it 'handles long messages' do
        long_message = 'A' * 2000
        action.send(:process_inputs, {
          'token' => 'test_token',
          'destination' => '123456',
          'message' => long_message
        })
        
        expect(discord_bot).to receive(:send_message).with('123456', long_message)
        action.invoke
      end
    end

    context 'when Discord service is unavailable' do
      before do
        allow(service_manager).to receive(:lookup).with(:DiscordService).and_return(nil)
        action.send(:process_inputs, {
          'token' => 'test_token',
          'destination' => '123456',
          'message' => 'Test message'
        })
      end

      it 'raises an error when Discord service is not available' do
        expect { action.invoke }.to raise_error(NoMethodError)
      end
    end

    context 'when bot operations fail' do
      before do
        action.send(:process_inputs, {
          'token' => 'test_token',
          'destination' => '123456',
          'message' => 'Test message'
        })
      end

      it 'handles bot creation failure gracefully' do
        allow(discord_service).to receive(:bot_for_token).and_raise(StandardError, 'Bot creation failed')
        expect { action.invoke }.to raise_error(StandardError, 'Bot creation failed')
      end

      it 'handles bot start failure gracefully' do
        allow(discord_bot).to receive(:start).and_raise(StandardError, 'Bot start failed')
        expect { action.invoke }.to raise_error(StandardError, 'Bot start failed')
      end

      it 'handles message send failure gracefully' do
        allow(discord_bot).to receive(:send_message).and_return(false)
        # Should not raise an error, just return false
        expect { action.invoke }.not_to raise_error
      end
    end
  end

  describe 'input validation' do
    it 'requires token input' do
      expect { 
        action.send(:process_inputs, { 
          'destination' => '123456', 
          'message' => 'test' 
        }) 
      }.to raise_error(CGE::InputError, /Required input token/)
    end

    it 'requires destination input' do
      expect { 
        action.send(:process_inputs, { 
          'token' => 'test_token', 
          'message' => 'test' 
        }) 
      }.to raise_error(CGE::InputError, /Required input destination/)
    end

    it 'requires message input' do
      expect { 
        action.send(:process_inputs, { 
          'token' => 'test_token', 
          'destination' => '123456' 
        }) 
      }.to raise_error(CGE::InputError, /Required input message/)
    end

    it 'validates token is a string' do
      expect { 
        action.send(:process_inputs, { 
          'token' => 12345, 
          'destination' => '123456', 
          'message' => 'test' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates destination is a string' do
      expect { 
        action.send(:process_inputs, { 
          'token' => 'test_token', 
          'destination' => 123456, 
          'message' => 'test' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates message is a string' do
      expect { 
        action.send(:process_inputs, { 
          'token' => 'test_token', 
          'destination' => '123456', 
          'message' => 123 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs' do
      expect { 
        action.send(:process_inputs, { 
          'token' => 'valid_token', 
          'destination' => 'valid_destination', 
          'message' => 'valid_message' 
        }) 
      }.not_to raise_error
    end
  end

  describe 'integration scenarios' do
    it 'works with empty message' do
      action.send(:process_inputs, {
        'token' => 'test_token',
        'destination' => '123456',
        'message' => ''
      })
      
      expect(discord_bot).to receive(:send_message).with('123456', '')
      action.invoke
    end

    it 'works with whitespace-only message' do
      action.send(:process_inputs, {
        'token' => 'test_token',
        'destination' => '123456',
        'message' => '   \n\t   '
      })
      
      expect(discord_bot).to receive(:send_message).with('123456', '   \n\t   ')
      action.invoke
    end

    it 'handles unicode messages' do
      unicode_message = '你好世界 🌍 こんにちは مرحبا 🎌'
      action.send(:process_inputs, {
        'token' => 'test_token',
        'destination' => '123456',
        'message' => unicode_message
      })
      
      expect(discord_bot).to receive(:send_message).with('123456', unicode_message)
      action.invoke
    end
  end

  describe 'thread safety' do
    it 'handles concurrent invocations safely' do
      action.send(:process_inputs, {
        'token' => 'test_token',
        'destination' => '123456',
        'message' => 'concurrent test'
      })

      # Allow multiple calls to send_message
      allow(discord_bot).to receive(:send_message).and_return(true)
      
      threads = []
      results = []
      
      5.times do
        threads << Thread.new do
          results << action.invoke
        end
      end
      
      threads.each(&:join)
      expect(results.size).to eq(5)
    end
  end
end