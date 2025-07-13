# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/services/discord_service'

RSpec.describe CGE::DiscordService do
  let(:service) { described_class.new }
  let(:test_token) { 'test_discord_token_123' }
  let(:test_token_2) { 'test_discord_token_456' }

  before do
    service.start
  end

  after do
    service.stop
  end

  describe '#bot_for_token' do
    it 'creates a new bot for a token' do
      bot = service.bot_for_token(test_token)
      expect(bot).to be_a(CGE::DiscordBot)
      expect(bot.token).to eq(test_token)
    end

    it 'returns the same bot for the same token' do
      bot1 = service.bot_for_token(test_token)
      bot2 = service.bot_for_token(test_token)
      expect(bot1).to be(bot2)
    end

    it 'creates different bots for different tokens' do
      bot1 = service.bot_for_token(test_token)
      bot2 = service.bot_for_token(test_token_2)
      expect(bot1).not_to be(bot2)
      expect(bot1.token).to eq(test_token)
      expect(bot2.token).to eq(test_token_2)
    end

    it 'is thread-safe' do
      bots = []
      threads = []

      10.times do
        threads << Thread.new do
          bots << service.bot_for_token(test_token)
        end
      end

      threads.each(&:join)
      expect(bots.uniq.size).to eq(1)
    end
  end

  describe '#destroy_bot' do
    it 'stops and removes a bot from the registry' do
      bot = service.bot_for_token(test_token)
      expect(bot).to receive(:stop)

      service.destroy_bot(bot)

      # Creating a new bot with the same token should return a different instance
      new_bot = service.bot_for_token(test_token)
      expect(new_bot).not_to be(bot)
    end

    it 'handles destroying non-existent bots gracefully' do
      fake_bot = double('FakeBot')
      allow(fake_bot).to receive(:stop)

      expect { service.destroy_bot(fake_bot) }.not_to raise_error
    end
  end

  describe '#perform_stop' do
    it 'stops all registered bots' do
      bot1 = service.bot_for_token(test_token)
      bot2 = service.bot_for_token(test_token_2)

      expect(bot1).to receive(:stop).at_least(:once)
      expect(bot2).to receive(:stop).at_least(:once)

      service.perform_stop
    end
  end
end

RSpec.describe CGE::DiscordBot do
  let(:test_token) { 'test_bot_token_789' }
  let(:bot) { described_class.new(test_token) }
  let(:mock_discord_bot) { double('Discordrb::Commands::CommandBot') }
  let(:mock_thread) { double('Thread') }

  before do
    # Mock the Discordrb library to avoid actual Discord connections
    allow(Discordrb::Commands::CommandBot).to receive(:new).and_return(mock_discord_bot)
    allow(mock_discord_bot).to receive(:message)
    allow(mock_discord_bot).to receive(:run)
    allow(mock_discord_bot).to receive(:stop)
    allow(mock_discord_bot).to receive(:bot_user).and_return(double('BotUser', id: 12345))
    allow(Thread).to receive(:new).and_yield.and_return(mock_thread)
    allow(mock_thread).to receive(:join)
    allow(mock_thread).to receive(:kill)
    allow(mock_thread).to receive(:alive?).and_return(false)
  end

  describe '#initialize' do
    it 'initializes with correct token and default state' do
      expect(bot.token).to eq(test_token)
      expect(bot.running?).to be false
    end
  end

  describe '#add_command and #remove_command' do
    it 'adds and removes command handlers' do
      handler_called = false
      handler = proc { |_event, _content| handler_called = true }

      bot.add_command('!test', &handler)
      expect(bot.instance_variable_get(:@commands)['!test']).to eq(handler)

      bot.remove_command('!test')
      expect(bot.instance_variable_get(:@commands)['!test']).to be_nil
    end

    it 'is thread-safe for command operations' do
      handlers = []
      threads = []

      10.times do |i|
        threads << Thread.new do
          bot.add_command("!test#{i}") { |_event, _content| "handler#{i}" }
        end
      end

      threads.each(&:join)
      expect(bot.instance_variable_get(:@commands).size).to eq(10)
    end
  end

  describe '#on_mention and #remove_mention_handler' do
    it 'sets and removes mention handlers' do
      handler_called = false
      handler = proc { |_event, _content| handler_called = true }

      test_obj = 'test_handler'
      bot.on_mention(test_obj, &handler)
      expect(bot.instance_variable_get(:@mention_handlers)[test_obj]).to eq(handler)

      bot.remove_mention_handler(test_obj)
      expect(bot.instance_variable_get(:@mention_handlers)[test_obj]).to be_nil
    end
  end

  describe '#start and #stop' do
    it 'starts the bot and sets running state' do
      expect(mock_discord_bot).to receive(:message)
      expect(mock_discord_bot).to receive(:run)

      bot.start
      expect(bot.running?).to be true
    end

    it 'does not start if already running' do
      bot.start
      expect(mock_discord_bot).not_to receive(:run)
      bot.start # Second call should be ignored
    end

    it 'stops the bot and cleans up resources' do
      bot.start
      expect(mock_discord_bot).to receive(:stop)
      expect(mock_thread).to receive(:join).with(5.0)

      bot.stop
      expect(bot.running?).to be false
    end

    it 'force kills thread if it does not stop gracefully' do
      allow(mock_thread).to receive(:alive?).and_return(true)
      expect(mock_thread).to receive(:kill)

      bot.start
      bot.stop
    end
  end

  describe '#send_message' do
    let(:mock_channel) { double('Channel') }
    let(:mock_user) { double('User') }

    before do
      bot.start
      allow(mock_discord_bot).to receive(:channel).and_return(mock_channel)
      allow(mock_discord_bot).to receive(:user).and_return(mock_user)
    end

    it 'sends message to channel by ID' do
      expect(mock_channel).to receive(:send_message).with('Hello!')
      result = bot.send_message('123456', 'Hello!')
      expect(result).not_to be false
    end

    it 'sends message to user by ID' do
      allow(mock_discord_bot).to receive(:channel).and_return(nil)
      expect(mock_user).to receive(:send_message).with('Hello!')
      bot.send_message('987654', 'Hello!')
    end

    it 'sends message to Discord object directly' do
      mock_destination = double('DiscordObject')
      expect(mock_destination).to receive(:send_message).with('Hello!')
      bot.send_message(mock_destination, 'Hello!')
    end

    it 'returns false if bot is not running' do
      bot.stop
      result = bot.send_message('123456', 'Hello!')
      expect(result).to be false
    end
  end

  describe 'message handling' do
    let(:mock_event) { double('MessageEvent') }
    let(:mock_message) { double('Message') }
    let(:mock_author) { double('Author', username: 'testuser') }
    let(:mock_bot_user) { double('BotUser', id: 12345) }

    before do
      allow(mock_event).to receive(:content).and_return('!test hello world')
      allow(mock_event).to receive(:message).and_return(mock_message)
      allow(mock_event).to receive(:author).and_return(mock_author)
      allow(mock_message).to receive(:mentions).and_return([])
      allow(mock_discord_bot).to receive(:bot_user).and_return(mock_bot_user)
    end

    it 'handles regular commands' do
      handler_called = false
      content_received = nil

      bot.add_command('!test') do |_event, content|
        handler_called = true
        content_received = content
      end

      # Simulate message handling
      bot.send(:handle_message, mock_event)

      # Wait for the handler thread to complete
      sleep(0.1)

      expect(handler_called).to be true
      expect(content_received).to eq(['hello', 'world'])
    end

    it 'handles mentions' do
      bot.start # Start the bot to initialize @bot
      
      mention_user = double('User', id: 12345)
      allow(mock_message).to receive(:mentions).and_return([mention_user])
      allow(mock_event).to receive(:content).and_return('<@12345> hello there')

      handler_called = false
      content_received = nil

      mention_handler_obj = 'mention_test'
      bot.on_mention(mention_handler_obj) do |_event, content|
        handler_called = true
        content_received = content
      end

      bot.send(:handle_message, mock_event)
      sleep(0.1)

      expect(handler_called).to be true
      expect(content_received).to eq('hello there')
    end

    it 'ignores empty messages' do
      allow(mock_event).to receive(:content).and_return('   ')
      
      handler_called = false
      bot.add_command('!test') { |_event, _content| handler_called = true }

      bot.send(:handle_message, mock_event)
      sleep(0.1)

      expect(handler_called).to be false
    end
  end
end