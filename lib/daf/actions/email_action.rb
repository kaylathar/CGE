require 'daf/action'
require 'net/smtp'

module DAF
  # An action that sends an email based on parameters
  class EmailAction < Action
    attr_option :to, String, :required
    attr_option :from, String, :required
    attr_option :subject, String, :required
    attr_option :body, String, :required
    attr_option :server, String, :required
    attr_option :port, Integer

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
