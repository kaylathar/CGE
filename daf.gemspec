# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'daf/version'

Gem::Specification.new do |spec|
  spec.name          = 'daf'
  spec.version       = DAF::VERSION
  spec.authors       = ['Kayla McArthur']
  spec.email         = ['kayla@kayla.is']
  spec.summary       = 'A daemon and framework for monitoring events, '\
                       'and triggering actions'
  spec.description   = 'A library and corresponding daemon based on that '\
                       'library to monitor a number of sources for events '\
                       'and trigger actions based on those events. '\
                       'Includes a default set of monitors and actions '\
                       'and tools to create more'
  spec.homepage      = 'http://github.com/klmcarthur/DAF'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'rspec'
end
