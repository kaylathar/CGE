require 'cge/action'
require 'twilio-ruby'

module CGE
  # An action that sends an sms using twilio based on parameters
  class SMSAction < Action
    attr_option :to, String, :required
    attr_option :message, String, :required
    attr_option :from, String, :required
    attr_option :sid, String, :required
    attr_option :token, String, :required

    attr_output :message_id, String

    def client
      @client ||= Twilio::REST::Client.new(sid.value, token.value)
    end

    def invoke
      @message_id = client.messages.create(body: message.value,
                                           to: to.value,
                                           from: from.value)
    end
  end
end
