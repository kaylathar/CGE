require 'daf/action'
require 'twilio-ruby'

module DAF
  # An action that sends an sms using twilio based on parameters
  class SMSAction < Action
    attr_option :to, String, :required
    attr_option :message, String, :required
    attr_option :from, String, :required
    attr_option :sid, String, :required
    attr_option :token, String, :required

    attr_output :message_id, String

    def client
      @client ||= Twilio::REST::Client.new(@sid, @token)
    end

    def invoke
      @message_id = client.account.messages.create(body: @message,
                                                   to: @to,
                                                   from: @from)
    end
  end
end
