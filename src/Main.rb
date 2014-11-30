require_relative "monitors/FileUpdateMonitor"
require_relative "actions/EmailAction"

monitor = FileUpdateMonitor.new(:path => "/tmp/test1", :frequency => 2)
action = EmailAction.new()

monitor.on_trigger do
  action.activate(:to => "test@example.com",
                  :from => "test@example.com",
                  :subject => "test subject",
                  :body => "test body") do
    puts "Email sent successful!"
  end
end

sleep(10000)
