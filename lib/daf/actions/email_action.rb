require 'daf/action'

# An action that sends an email based on parameters
class EmailAction < Action
  attr_option :to, String
  attr_option :from, String
  attr_option :subject, String
  attr_option :body, String

  def invoke
    message = format_email(@to.value, @from.value, @subject.value, @body.value)
    # Send using Net::SMTP or sendmail or whatever, for now log
    puts message
    true
  end

  def format_email(to, from, subject, body)
    <<TEXT
From: #{from}
To: #{to}
Subject: #{subject}

#{body}
TEXT
  end
end
