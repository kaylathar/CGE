require 'spec_helper'
require 'tempfile'

describe CGE::GlobalConfiguration do
  let(:yaml_content) { "heartbeat: 30\n" }
  let(:json_content) { '{"heartbeat": 60}' }
  let(:invalid_yaml) { "heartbeat: -5\n" }
  let(:invalid_json) { '{"heartbeat": "not_a_number"}' }

  describe '#initialize' do
    it 'parses YAML configuration file' do
      Tempfile.create(['config', '.yml']) do |file|
        file.write(yaml_content)
        file.rewind
        
        config = CGE::GlobalConfiguration.new(file.path)
        expect(config.heartbeat.value).to eq(30)
      end
    end

    it 'parses JSON configuration file' do
      Tempfile.create(['config', '.json']) do |file|
        file.write(json_content)
        file.rewind
        
        config = CGE::GlobalConfiguration.new(file.path)
        expect(config.heartbeat.value).to eq(60)
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

  describe 'heartbeat input' do
    it 'accepts valid heartbeat values' do
      config = CGE::GlobalConfiguration.new
      config.heartbeat.value = 60
      expect(config.heartbeat.valid?).to be true
    end

    it 'rejects negative heartbeat values' do
      config = CGE::GlobalConfiguration.new
      config.heartbeat.value = -5
      expect(config.heartbeat.valid?).to be false
    end

    it 'rejects zero heartbeat values' do
      config = CGE::GlobalConfiguration.new
      config.heartbeat.value = 0
      expect(config.heartbeat.valid?).to be false
    end

    it 'rejects non-integer heartbeat values' do
      config = CGE::GlobalConfiguration.new
      config.heartbeat.value = 'not_a_number'
      expect(config.heartbeat.valid?).to be false
    end
  end

  describe 'validation' do
    it 'validates inputs during initialization' do
      Tempfile.create(['config', '.yml']) do |file|
        file.write(invalid_yaml)
        file.rewind
        
        expect { CGE::GlobalConfiguration.new(file.path) }
          .to raise_error(CGE::InputError, /Bad value for input heartbeat/)
      end
    end
  end
end