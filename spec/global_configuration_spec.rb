require 'spec_helper'
require 'tempfile'

describe CGE::GlobalConfiguration do
  let(:yaml_content) { "heartbeat: 30\n" }
  let(:json_content) { '{"heartbeat": 60}' }
  let(:invalid_yaml) { "heartbeat: -5\n" }
  let(:invalid_json) { '{"heartbeat": "not_a_number"}' }
  let(:unknown_option_yaml) { "heartbeat: 30\nunknown_option: test\n" }

  describe '#initialize' do
    it 'uses default values when no file provided' do
      config = CGE::GlobalConfiguration.new
      expect(config.heartbeat).to eq(60)
    end

    it 'parses YAML configuration file' do
      Tempfile.create(['config', '.yml']) do |file|
        file.write(yaml_content)
        file.rewind
        
        config = CGE::GlobalConfiguration.new(file.path)
        expect(config.heartbeat).to eq(30)
      end
    end

    it 'parses JSON configuration file' do
      Tempfile.create(['config', '.json']) do |file|
        file.write(json_content)
        file.rewind
        
        config = CGE::GlobalConfiguration.new(file.path)
        expect(config.heartbeat).to eq(60)
      end
    end

    it 'warns and ignores unknown configuration options' do
      Tempfile.create(['config', '.yml']) do |file|
        file.write(unknown_option_yaml)
        file.rewind
        
        expect { CGE::GlobalConfiguration.new(file.path) }
          .to output(/Unknown configuration option 'unknown_option' ignored/).to_stderr
      end
    end

    it 'raises error for unsupported file format' do
      Tempfile.create(['config', '.txt']) do |file|
        file.write('heartbeat: 30')
        file.rewind
        
        expect { CGE::GlobalConfiguration.new(file.path) }
          .to raise_error(CGE::GlobalConfigurationError, /Unsupported configuration file format/)
      end
    end

    it 'raises error for invalid YAML' do
      Tempfile.create(['config', '.yml']) do |file|
        file.write('invalid: yaml: content:')
        file.rewind
        
        expect { CGE::GlobalConfiguration.new(file.path) }
          .to raise_error(CGE::GlobalConfigurationError, /Failed to parse configuration file/)
      end
    end
  end

  describe 'heartbeat accessor' do
    it 'returns default heartbeat value' do
      config = CGE::GlobalConfiguration.new
      expect(config.heartbeat).to eq(60)
    end
  end

  describe 'validation' do
    it 'validates inputs during initialization' do
      Tempfile.create(['config', '.yml']) do |file|
        file.write(invalid_yaml)
        file.rewind
        
        expect { CGE::GlobalConfiguration.new(file.path) }
          .to raise_error(CGE::GlobalConfigurationError, /Invalid value for heartbeat: -5/)
      end
    end

    it 'validates inputs with non-integer types' do
      Tempfile.create(['config', '.json']) do |file|
        file.write(invalid_json)
        file.rewind
        
        expect { CGE::GlobalConfiguration.new(file.path) }
          .to raise_error(CGE::GlobalConfigurationError, /Invalid value for heartbeat: "not_a_number"/)
      end
    end
  end
end