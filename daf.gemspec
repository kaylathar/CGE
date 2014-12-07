# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'daf/version'

Gem::Specification.new do |spec|
  spec.name          = "daf"
  spec.version       = Daf::VERSION
  spec.authors       = ["Kayla McArthur"]
  spec.email         = ["kayla@kayla.is"]
  spec.summary       = %q{A daemon and framework for monitoring for events, and triggering actions}
  spec.homepage      = "http://github.com/klmcarthur/DAF"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "rspec"
end
