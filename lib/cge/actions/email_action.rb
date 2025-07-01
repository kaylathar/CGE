require 'cge/action'
require 'net/smtp'

module CGE
  # An action that sends an email based on parameters
  class EmailAction < Action
    attr_input :to, String, :required
    attr_input :from, String, :required
    attr_input :subject, String, :required
    attr_input :body, String, :required
    attr_input :server, String, :required
    attr_input :port, Integer

    def invoke
      message = format_email(@to.value, @from.value,
                             @subject.value, @body.value)
      port = self.port.valid? ? self.port.value : 25
      Net::SMTP.start(@server.value, port) do |smtp|
        smtp.send_message(message, @from.value, @to.value)
      end
    end

    def format_email(to, from, subject, body)
      <<TEXT
  From: #{from}
  To: #{to}
  Subject: #{subject}

  #{body}
TEXT
    end

    private :format_email
  end
end

CGE::Command.register_command(CGE::EmailAction)
