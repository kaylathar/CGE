require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_group 'Actions', 'lib/cge/actions/'
  add_group 'Monitors', 'lib/cge/monitors/'
  add_group 'Inputs', 'lib/cge/inputs/'
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
require 'cge/actions/email_action'
require 'cge/actions/shell_action'
require 'cge/inputs/constant_input'
require 'cge/inputs/file_input'
require 'cge/inputs/google_doc_input'
require 'cge/inputs/ocr_input'
require 'cge/inputs/web_input'
require 'cge/conditionals/comparison_conditional'
require 'cge/datasources/yaml_command_graph'
require 'cge/global_configuration'
