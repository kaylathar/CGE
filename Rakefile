# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'bundler/gem_tasks'
Bundler.setup(:default, :development)
require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task default: :validate

desc 'Validate Package'
task validate: %i[rubocop spec]

desc 'Run RuboCop'
task :rubocop do
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
end

desc 'Build Documentation'
task :yard do
  require 'yard'
  YARD::Rake::YardocTask.new
end
