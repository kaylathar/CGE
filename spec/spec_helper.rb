require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_group 'Actions', 'lib/daf/actions/'
  add_group 'Monitors', 'lib/daf/monitors/'
  minimum_coverage 95
  refuse_coverage_drop
end

require 'daf'
require 'daf/command_graph'
require 'daf/configurable'
require 'daf/monitor'
require 'daf/action'
require 'daf/monitors/file_update_monitor'
require 'daf/actions/email_action'
require 'daf/actions/shell_action'
require 'daf/datasources/yaml_command_graph'
