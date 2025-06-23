require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_group 'Actions', 'lib/cge/actions/'
  add_group 'Monitors', 'lib/cge/monitors/'
  add_group 'Inputs', 'lib/cge/inputs/'
  add_group 'Conditionals', 'lib/cge/conditionals/'
  add_group 'Parsers', 'lib/cge/graphs/'
  minimum_coverage 95
  refuse_coverage_drop
end

require 'cge'
require 'cge/command_graph'
require 'cge/configurable'
require 'cge/monitor'
require 'cge/action'
require 'cge/input'
require 'cge/conditional'
require 'cge/monitors/file_update_monitor'
require 'cge/monitors/cron_monitor'
require 'cge/monitors/unix_socket_monitor'
require 'cge/actions/email_action'
require 'cge/actions/shell_action'
require 'cge/actions/sms_action'
require 'cge/actions/file_action'
require 'cge/actions/dropbox_file_action'

require 'cge/inputs/constant_input'
require 'cge/inputs/file_input'
require 'cge/inputs/google_doc_input'
require 'cge/inputs/ocr_input'
require 'cge/inputs/web_input'
require 'cge/conditionals/comparison_conditional'
require 'cge/graphs/yaml_command_graph'
require 'cge/global_configuration'

# Manually register all command classes for testing
# This ensures they're available for secure const_get in JSON/YAML parsers
CGE::Command.register_command(CGE::FileUpdateMonitor)
CGE::Command.register_command(CGE::CronMonitor)
CGE::Command.register_command(CGE::UnixSocketMonitor)
CGE::Command.register_command(CGE::EmailAction)
CGE::Command.register_command(CGE::ShellAction)
CGE::Command.register_command(CGE::SMSAction)
CGE::Command.register_command(CGE::FileAction)
CGE::Command.register_command(CGE::DropboxFileAction)

CGE::Command.register_command(CGE::ConstantInput)
CGE::Command.register_command(CGE::FileInput)
CGE::Command.register_command(CGE::GoogleDocInput)
CGE::Command.register_command(CGE::OCRInput)
CGE::Command.register_command(CGE::WebInput)
CGE::Command.register_command(CGE::ComparisonConditional)
