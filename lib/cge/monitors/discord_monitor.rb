# frozen_string_literal: true

require 'cge/monitor'

module CGE
  # Monitor that listens for messages via a bot on Discord
  class DiscordMonitor < Monitor
    # The token used for authentication
    attr_input :token, String, :required do |val|
      !val.empty?
    end

    # The watch character or token to listen for and trigger response. Either
    # this or enable_mention must be set.
    attr_input :command_token, String do |val|
      !val.empty?
    end

    # Boolean, if true enables triggering on a mention, this or command_token must be set.
    aatr_input :enable_mention, Object

    attr_output :sender, String
    attr_output :content, String
    attr_output :channel, String
    attr_output :message_id, String

    def block_until_triggered
      @triggered = false
      @trigger_mutex = Mutex.new
      @trigger_condition = ConditionVariable.new

      discord_service = service_manager.lookup(:DiscordService)
      bot = discord_service.bot_for_token(token.value)

      # Register command handler with the bot
      if enable_mention.value
        register_mention_handler(bot)
      else
        register_command_handler(bot)
      end

      # Start the bot if it's not already running
      bot.start unless bot.running?

      # Block until triggered
      @trigger_mutex.synchronize do
        @trigger_condition.wait(@trigger_mutex) until @triggered
      end
    end

    private

    # Register the command handler with the Discord bot
    # @param bot [DiscordBot] The Discord bot instance
    def register_command_handler(bot)
      command_token_value = command_token.value

      bot.add_command(command_token_value) do |event, args|
        handle_discord_command(event, args.join(' '))
      end
    end

    def register_mention_handler(bot)
      bot.on_mention do |event, clean_content|
        handle_discord_command(event, words)
      end
    end

    def handle_discord_trigger(event, content)
      @trigger_mutex.synchronize do
        return if @triggered

        @sender = event.author.username
        @content = content
        @channel = event.channel.id.to_s
        @message_id = event.message.id.to_s

        @triggered = true
        @trigger_condition.signal
      end
    end
  end
end
CGE::Command.register_command(CGE::DiscordMonitor)
