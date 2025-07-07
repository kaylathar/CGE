# frozen_string_literal: true

require 'cge/service'
require 'discordrb'
require 'cge/service_manager'

module CGE
  # Discord service for managing multiple Discord bots
  class DiscordService < Service
    def initialize
      @token_to_bots = {}
      @service_mutex = Mutex.new
      super
    end

    # Get or create a bot for the given token
    # @param token [String] Discord bot token
    # @return [DiscordBot] Bot instance for the token
    def bot_for_token(token)
      @service_mutex.synchronize do
        @token_to_bots[token] ||= DiscordBot.new(token)
      end
    end

    # Destroy a bot and remove it from the registry
    # @param bot [DiscordBot] Bot to destroy
    def destroy_bot(bot)
      @service_mutex.synchronize do
        bot.stop
        @token_to_bots.delete_if { |_token, b| b == bot }
      end
    end

    # Start all registered bots
    def perform_start
      # No-op, bots should start only when requested by clients
    end

    # Stop all registered bots
    def perform_stop
      @service_mutex.synchronize do
        @token_to_bots.each_value(&:stop)
      end
    end
  end

  # Discord bot wrapper
  class DiscordBot
    attr_reader :token, :bot

    def initialize(token)
      @token = token
      @bot = nil
      @commands = {}
      @mention_handlers = {}
      @bot_mutex = Mutex.new
      @thread = nil
      @running = false
    end

    # Add a command handler
    # @param command_token [String] String to watch for at start of message
    # @param block [Proc] Block to execute when triggered
    # Block receives (event, message_content)
    def add_command(command_token, &block)
      @bot_mutex.synchronize do
        @commands[command_token] = block
      end
    end

    # Remove a command handler
    # @param command_token [String] Command token to remove
    def remove_command(command_token)
      @bot_mutex.synchronize do
        @commands.delete(command_token)
      end
    end

    # Set a handler for when the bot is mentioned
    # @param obj [Object] An object that can act as a hash key
    # for this handler, should be unique
    # @param block [Proc] Block to execute when triggered
    # Block receives (event, message_content)
    def on_mention(obj, &block)
      @bot_mutex.synchronize do
        @mention_handlers[obj] = block
      end
    end

    # Remove the mention handler
    def remove_mention_handler(obj)
      @bot_mutex.synchronize do
        @mention_handlers.delete(obj)
      end
    end

    # Start the Discord bot
    def start
      @bot_mutex.synchronize do
        return if @running

        @bot = Discordrb::Commands::CommandBot.new(token: @token)
        @bot.message do |event|
          handle_message(event)
        end
        @running = true

        @thread = Thread.new do
          @bot.run
        end
      end
    end

    # Stop the Discord bot
    def stop
      @bot_mutex.synchronize do
        return unless @running

        @bot&.stop
        @thread&.join(5.0) # Wait up to 5 seconds for clean shutdown
        @thread&.kill if @thread&.alive? # Force kill if still running
        @thread = nil
        @bot = nil
        @running = false
      end
    end

    # Check if the bot is running
    def running?
      @bot_mutex.synchronize do
        @running
      end
    end

    # Send a message to a specific destination
    # @param destination [String, Integer, Object] Channel ID, user ID, or Discord object
    # @param message [String] Message text to be sent
    def send_message(destination, message)
      @bot_mutex.synchronize do
        return false unless @running && @bot

        case destination
        when String, Integer
          # Assume it's a channel or user ID
          channel_or_user = @bot.channel(destination) || @bot.user(destination)
          channel_or_user&.send_message(message)
        else
          # Assume it's already a Discord object that can receive messages
          destination.send_message(message)
        end
      end
    end

    private

    # Handle incoming messages and check for commands
    # @param event [Discordrb::Events::MessageEvent] Discord message event
    def handle_message(event)
      message_content = event.content.strip
      return if message_content.empty?

      if event.message.mentions.any? { |user| user.id == @bot.bot_user.id }
        handle_mention(event, message_content)
      else
        handle_regular_command(event, message_content)
      end
    end

    # Handle messages where the bot is mentioned
    def handle_mention(event, message_content)
      @bot_mutex.synchronize do
        return unless @mention_handlers

        # Get clean content with mentions removed for the handler
        clean_content = get_clean_content_without_mentions(event, message_content)

        # Execute mention handler in a separate thread
        Thread.new do
          @mention_handlers.each_value do |handler|
            handler.call(event, clean_content)
          end
        end
      end
    end

    # Handle regular command messages (not mentions)
    def handle_regular_command(event, message_content)
      words = message_content.split
      return if words.empty?

      command_token = words.first
      args = words[1..-1]

      execute_command_if_exists(command_token, event, args)
    end

    # Execute a command if it exists in the commands registry
    def execute_command_if_exists(command_token, event, args)
      @bot_mutex.synchronize do
        command_handler = @commands[command_token]
        return unless command_handler

        Thread.new do
          command_handler.call(event, args)
        end
      end
    end

    # Get message content with all mentions removed
    def get_clean_content_without_mentions(event, message_content)
      clean_content = message_content.dup
      event.message.mentions.each do |user|
        clean_content.gsub!(/<@!?#{user.id}>/, '')
      end
      clean_content.strip
    end
  end
end

CGE::ServiceManager.register_service(:DiscordService, CGE::DiscordService)
