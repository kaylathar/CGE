require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_group 'Actions', 'lib/daf/actions/'
  add_group 'Monitors', 'lib/daf/monitors/'
end

require 'daf'
require 'daf/command'
require 'daf/configurable'
require 'daf/monitor'
require 'daf/action'
require 'daf/monitors/file_update_monitor'
require 'daf/actions/email_action'
require 'daf/datasources/yaml_data_source'
