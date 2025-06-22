lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cge/version'

Gem::Specification.new do |spec|
  spec.name          = 'cge'
  spec.version       = CGE::VERSION
  spec.authors       = ['Kayla McArthur']
  spec.email         = ['kayla@kayla.is']
  spec.summary       = 'A command graph executor for monitoring events, ' \
                       'and triggering actions'
  spec.description   = 'A library and corresponding executor based on that ' \
                       'library to monitor a number of sources for events ' \
                       'and trigger actions based on those events. ' \
                       'Includes a default set of monitors and actions ' \
                       'and tools to create more'
  spec.homepage      = 'http://github.com/klmcarthur/CGE'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.0.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'webmock'
  spec.add_dependency 'google-apis-docs_v1', '~> 0.33'
  spec.add_dependency 'google-apis-sheets_v4', '~> 0.28'
  spec.add_dependency 'net-http', '~> 0.4'
  spec.add_dependency 'net-smtp'
  spec.add_dependency 'nokogiri', '~> 1.15'
  spec.add_dependency 'rtesseract', '~> 3.1'
  spec.add_dependency 'sqlite3'
  spec.add_dependency 'twilio-ruby'
  spec.add_dependency 'washbullet'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
