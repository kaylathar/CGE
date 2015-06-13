require 'daf/action'
require 'washbullet'

module DAF
  # An action that sends an sms using twilio based on parameters
  class PushbulletAction < Action
    attr_option :key, String, :required
    attr_option :identifier, String, :required
    attr_option :title, String, :required
    attr_option :message, String, :required

    def client
      @client ||= Washbullet::Client.new(@key)
    end

    def invoke
      client.push_note(receiver:   :device,
                       identifier: @identifier,
                       params: {
                         title: @title,
                         body:  @message
                       }
                      )
    end
  end
end
