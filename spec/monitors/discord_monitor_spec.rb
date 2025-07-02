# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/monitors/discord_monitor'

RSpec.describe CGE::DiscordMonitor do
  let(:service_manager) { instance_double('CGE::ServiceManager') }
  let(:discord_service) { instance_double('CGE::DiscordService') }
  let(:discord_bot) { instance_double('CGE::DiscordBot') }
  let(:monitor) { described_class.new('monitor_id', 'test_monitor', {}, nil, nil, service_manager) }

  before do
    allow(service_manager).to receive(:lookup).with(:DiscordService).and_return(discord_service)
    allow(discord_service).to receive(:bot_for_token).and_return(discord_bot)
    allow(discord_bot).to receive(:start)
    allow(discord_bot).to receive(:running?).and_return(false)
    allow(discord_bot).to receive(:add_command)
    allow(discord_bot).to receive(:on_mention)
  end

  describe '#block_until_triggered with command token' do
    before do
      monitor.send(:process_inputs, {
        'token' => 'test_token',
        'command_token' => '!test'
      })
    end

    it 'registers a command handler with the Discord bot' do
      expect(discord_bot).to receive(:add_command).with('!test')
      
      # Start monitoring in a separate thread to avoid blocking
      monitor_thread = Thread.new { monitor.block_until_triggered }
      
      # Give the monitor time to set up
      sleep(0.1)
      
      # Simulate command trigger
      monitor.send(:handle_discord_trigger, mock_discord_event, 'hello world')
      
      # Wait for monitor to complete
      monitor_thread.join(1.0)
      
      expect(monitor.sender).to eq('testuser')
      expect(monitor.content).to eq('hello world')
      expect(monitor.channel).to eq('123456')
      expect(monitor.message_id).to eq('789012')
    end

    it 'starts the bot if not already running' do
      expect(discord_bot).to receive(:start)
      
      monitor_thread = Thread.new { monitor.block_until_triggered }
      sleep(0.1)
      monitor.send(:handle_discord_trigger, mock_discord_event, 'test')
      monitor_thread.join(1.0)
    end

    it 'only triggers once for multiple messages' do
      trigger_count = 0
      
      # Mock the condition variable to count triggers
      allow_any_instance_of(ConditionVariable).to receive(:signal) do
        trigger_count += 1
      end
      
      monitor_thread = Thread.new { monitor.block_until_triggered }
      sleep(0.1)
      
      # Send multiple triggers
      3.times do
        monitor.send(:handle_discord_trigger, mock_discord_event, 'test')
      end
      
      monitor_thread.join(1.0)
      expect(trigger_count).to eq(1)
    end
  end

  describe '#block_until_triggered with mention' do
    before do
      monitor.send(:process_inputs, {
        'token' => 'test_token',
        'enable_mention' => true
      })
    end

    it 'registers a mention handler with the Discord bot' do
      expect(discord_bot).to receive(:on_mention)
      
      monitor_thread = Thread.new { monitor.block_until_triggered }
      sleep(0.1)
      monitor.send(:handle_discord_trigger, mock_discord_event, 'mentioned content')
      monitor_thread.join(1.0)
      
      expect(monitor.content).to eq('mentioned content')
    end
  end

  describe 'input validation' do
    it 'requires token input' do
      expect { monitor.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input token/)
    end

    it 'validates token is not empty' do
      expect { monitor.send(:process_inputs, { 'token' => '' }) }.to raise_error(CGE::InputError)
    end

    it 'validates command_token is not empty when provided' do
      expect { 
        monitor.send(:process_inputs, { 
          'token' => 'valid_token', 
          'command_token' => '' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs' do
      expect { 
        monitor.send(:process_inputs, { 
          'token' => 'valid_token', 
          'command_token' => '!valid' 
        }) 
      }.not_to raise_error
    end
  end

  describe 'output attributes' do
    before do
      monitor.send(:process_inputs, {
        'token' => 'test_token',
        'command_token' => '!test'
      })
    end

    it 'provides access to sender, content, channel, and message_id' do
      expect(monitor).to respond_to(:sender)
      expect(monitor).to respond_to(:content)
      expect(monitor).to respond_to(:channel)
      expect(monitor).to respond_to(:message_id)
    end

    it 'sets output attributes when triggered' do
      monitor_thread = Thread.new { monitor.block_until_triggered }
      sleep(0.1)
      
      monitor.send(:handle_discord_trigger, mock_discord_event, 'test content')
      monitor_thread.join(1.0)
      
      expect(monitor.sender).to eq('testuser')
      expect(monitor.content).to eq('test content')
      expect(monitor.channel).to eq('123456')
      expect(monitor.message_id).to eq('789012')
    end
  end

  describe 'thread safety' do
    before do
      monitor.send(:process_inputs, {
        'token' => 'test_token',
        'command_token' => '!test'
      })
    end

    it 'handles concurrent trigger attempts safely' do
      monitor_thread = Thread.new { monitor.block_until_triggered }
      sleep(0.1)
      
      # Try to trigger from multiple threads simultaneously
      trigger_threads = []
      3.times do |i|
        trigger_threads << Thread.new do
          event = mock_discord_event("user#{i}", "content#{i}")
          monitor.send(:handle_discord_trigger, event, "content#{i}")
        end
      end
      
      trigger_threads.each(&:join)
      monitor_thread.join(1.0)
      
      # Should only capture the first trigger
      expect(monitor.content).to match(/content[0-2]/)
    end
  end

  private

  def mock_discord_event(username = 'testuser', content = 'test message')
    author = double('Author', username: username)
    channel = double('Channel', id: 123456)
    message = double('Message', id: 789012)
    
    double('MessageEvent',
      author: author,
      channel: channel,
      message: message,
      content: content
    )
  end
end