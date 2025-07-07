# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CGE::AtProtoMonitor do
  let(:monitor) { described_class.new('monitor_id', 'test_monitor', {}, nil, nil, nil) }
  let(:mock_bsky) { instance_double('Minisky') }
  let(:mock_firehose) { instance_double('Skyfall::Firehose') }

  before do
    # Mock Minisky
    allow(Minisky).to receive(:new).and_return(mock_bsky)
    allow(mock_bsky).to receive(:get_request).and_return({
                                                           'feed' => [
                                                             {
                                                               'post' => {
                                                                 'author' => { 'handle' => 'testuser.bsky.social' },
                                                                 'record' => { 'text' => 'Hello world test message',
                                                                               'createdAt' => '2023-01-01T00:00:00Z' },
                                                                 'uri' => 'at://did:plc:test/app.bsky.feed.post/test123'
                                                               }
                                                             }
                                                           ]
                                                         })

    # Mock Skyfall
    allow(Skyfall::Firehose).to receive(:new).and_return(mock_firehose)
    allow(mock_firehose).to receive(:on_message)
    allow(mock_firehose).to receive(:connect)

    # Mock Tempfile
    mock_tempfile = instance_double('Tempfile')
    allow(Tempfile).to receive(:new).and_return(mock_tempfile)
    allow(mock_tempfile).to receive(:chmod)
    allow(mock_tempfile).to receive(:write)
    allow(mock_tempfile).to receive(:close)
    allow(mock_tempfile).to receive(:path).and_return('/tmp/test_config.yml')
    allow(mock_tempfile).to receive(:unlink)
  end

  describe 'firehose setup' do
    it 'creates skyfall firehose connection with default relay' do
      monitor.send(:process_inputs, {
                     'search_text' => 'test'
                   })

      expect(Skyfall::Firehose).to receive(:new).with('bsky.network', :subscribe_repos)

      # Test the setup method directly to avoid threads
      monitor.send(:setup_firehose_connection)
    end

    it 'uses custom pds host when provided' do
      monitor.send(:process_inputs, {
                     'search_text' => 'test',
                     'pds_host' => 'custom.pds.host'
                   })

      expect(Skyfall::Firehose).to receive(:new).with('custom.pds.host', :subscribe_repos)

      # Test the setup method directly
      monitor.send(:setup_firehose_connection)
    end
  end

  describe '#handle_post_match' do
    it 'sets output attributes when a matching post is found' do
      # Initialize the monitor state first
      monitor.instance_variable_set(:@triggered, false)
      monitor.instance_variable_set(:@trigger_mutex, Mutex.new)
      monitor.instance_variable_set(:@trigger_condition, ConditionVariable.new)

      # Mock operation object that matches the skyfall structure
      operation = double('Operation')
      allow(operation).to receive(:repo).and_return('did:plc:test123')
      allow(operation).to receive(:raw_record).and_return({
                                                            'text' => 'Hello world test message',
                                                            'createdAt' => '2023-01-01T00:00:00Z'
                                                          })
      allow(operation).to receive(:uri).and_return('at://did:plc:test/app.bsky.feed.post/test123')

      monitor.send(:handle_post_match, operation)

      expect(monitor.author).to eq('did:plc:test123')
      expect(monitor.content).to eq('Hello world test message')
      expect(monitor.uri).to eq('at://did:plc:test/app.bsky.feed.post/test123')
      expect(monitor.created_at).to eq('2023-01-01T00:00:00Z')
    end

    it 'only triggers once for multiple matches' do
      # Initialize the monitor state first
      monitor.instance_variable_set(:@triggered, false)
      monitor.instance_variable_set(:@trigger_mutex, Mutex.new)
      condition_var = ConditionVariable.new
      monitor.instance_variable_set(:@trigger_condition, condition_var)

      trigger_count = 0
      allow(condition_var).to receive(:signal) do
        trigger_count += 1
      end

      # Send multiple triggers
      3.times do |i|
        operation = double('Operation')
        allow(operation).to receive(:repo).and_return("did:plc:user#{i}")
        allow(operation).to receive(:raw_record).and_return({
                                                              'text' => "test message #{i}",
                                                              'createdAt' => '2023-01-01T00:00:00Z'
                                                            })
        allow(operation).to receive(:uri).and_return("at://did:plc:test/app.bsky.feed.post/test#{i}")

        monitor.send(:handle_post_match, operation)
      end

      expect(trigger_count).to eq(1)
    end
  end

  describe 'input validation' do
    it 'requires search_text input' do
      expect { monitor.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input search_text/)
    end

    it 'validates search_text is not empty' do
      expect do
        monitor.send(:process_inputs, { 'search_text' => '' })
      end.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs for firehose mode' do
      expect do
        monitor.send(:process_inputs, { 'search_text' => 'test' })
      end.not_to raise_error
    end

    it 'accepts valid inputs with optional handle and password' do
      expect do
        monitor.send(:process_inputs, {
                       'handle' => 'test.bsky.social',
                       'password' => 'test_password',
                       'search_text' => 'test'
                     })
      end.not_to raise_error
    end
  end

  describe 'output attributes' do
    it 'provides access to author, content, uri, and created_at' do
      expect(monitor).to respond_to(:author)
      expect(monitor).to respond_to(:content)
      expect(monitor).to respond_to(:uri)
      expect(monitor).to respond_to(:created_at)
    end
  end
end
