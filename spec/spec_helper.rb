require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_group 'Actions', 'lib/daf/actions/'
  add_group 'Monitors', 'lib/daf/monitors/'
  add_group 'Inputs', 'lib/daf/inputs/'
  minimum_coverage 95
  refuse_coverage_drop
end

require 'daf'
require 'daf/command_graph'
require 'daf/configurable'
require 'daf/monitor'
require 'daf/action'
require 'daf/input'
require 'daf/monitors/file_update_monitor'
require 'daf/actions/email_action'
require 'daf/actions/shell_action'
require 'daf/inputs/constant_input'
require 'daf/inputs/file_input'
require 'daf/inputs/google_doc_input'
require 'daf/datasources/yaml_command_graph'
require 'daf/global_configuration'
