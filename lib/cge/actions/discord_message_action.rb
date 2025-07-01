# frozen_string_literal: true

require 'cge/action'

module CGE
  # Action that sends a Discord message using the Discord service
  class DiscordMessageAction < Action
    attr_input :token, String, :required
    attr_input :destination, String, :required
    attr_input :message, String, :required

    def invoke
      discord_service = service_manager.lookup(:DiscordService)
      bot = discord_service.bot_for_token(token.value)

      # Ensure bot is running
      bot.start unless bot.running?

      # Send the message
      bot.send_message(destination.value, message.value)
    end
  end
end

CGE::Command.register_command(CGE::DiscordMessageAction)
