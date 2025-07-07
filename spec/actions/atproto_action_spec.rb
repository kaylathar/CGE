# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CGE::AtProtoAction do
  let(:action) { described_class.new('action_id', 'test_action', {}, nil, nil, nil) }
  let(:mock_bsky) { double('Minisky') }
  let(:mock_user) { double('User', did: 'did:plc:test123') }

  before do
    # Mock Minisky class and instance
    allow(Minisky).to receive(:new).and_return(mock_bsky)
    allow(mock_bsky).to receive(:user).and_return(mock_user)
    allow(mock_bsky).to receive(:post_request).and_return({
                                                            'uri' => 'at://did:plc:test123/app.bsky.feed.post/test456',
                                                            'cid' => 'test_cid'
                                                          })

    # Mock Tempfile
    mock_tempfile = instance_double('Tempfile')
    allow(Tempfile).to receive(:new).and_return(mock_tempfile)
    allow(mock_tempfile).to receive(:chmod)
    allow(mock_tempfile).to receive(:write)
    allow(mock_tempfile).to receive(:close)
    allow(mock_tempfile).to receive(:path).and_return('/tmp/test_config.yml')
    allow(mock_tempfile).to receive(:unlink)
  end

  describe '#invoke' do
    before do
      action.send(:process_inputs, {
                    'handle' => 'test.bsky.social',
                    'password' => 'test_password',
                    'text' => 'Hello world from CGE!'
                  })
    end

    it 'creates minisky client and posts message' do
      expect(Minisky).to receive(:new).with('bsky.social', '/tmp/test_config.yml')
      expect(mock_bsky).to receive(:post_request) do |method, params|
        expect(method).to eq('com.atproto.repo.createRecord')
        expect(params[:repo]).to eq('did:plc:test123')
        expect(params[:collection]).to eq('app.bsky.feed.post')
        expect(params[:record][:text]).to eq('Hello world from CGE!')
        expect(params[:record][:langs]).to eq(['en'])
      end

      action.invoke
    end

    it 'uses custom PDS host when provided' do
      action.send(:process_inputs, {
                    'handle' => 'test.bsky.social',
                    'password' => 'test_password',
                    'text' => 'Hello world from CGE!',
                    'pds_host' => 'custom.pds.host'
                  })

      expect(Minisky).to receive(:new).with('custom.pds.host', '/tmp/test_config.yml')
      action.invoke
    end
  end

  describe 'input validation' do
    it 'requires handle input' do
      expect { action.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input handle/)
    end

    it 'requires password input' do
      expect { action.send(:process_inputs, { 'handle' => 'test.bsky.social' }) }.to raise_error(CGE::InputError, /Required input password/)
    end

    it 'requires text input' do
      expect do
        action.send(:process_inputs, {
                      'handle' => 'test.bsky.social',
                      'password' => 'test_password'
                    })
      end.to raise_error(CGE::InputError, /Required input text/)
    end

    it 'validates text length' do
      expect do
        action.send(:process_inputs, {
                      'handle' => 'test.bsky.social',
                      'password' => 'test_password',
                      'text' => 'x' * 301
                    })
      end.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs' do
      expect do
        action.send(:process_inputs, {
                      'handle' => 'test.bsky.social',
                      'password' => 'test_password',
                      'text' => 'Valid post text'
                    })
      end.not_to raise_error
    end
  end

  describe 'file cleanup' do
    it 'cleans up temporary config file even on error' do
      mock_tempfile = instance_double('Tempfile')
      allow(Tempfile).to receive(:new).and_return(mock_tempfile)
      allow(mock_tempfile).to receive(:chmod)
      allow(mock_tempfile).to receive(:write)
      allow(mock_tempfile).to receive(:close)
      allow(mock_tempfile).to receive(:path).and_return('/tmp/test_config.yml')
      allow(mock_tempfile).to receive(:unlink)

      allow(Minisky).to receive(:new).and_raise('Connection error')

      action.send(:process_inputs, {
                    'handle' => 'test.bsky.social',
                    'password' => 'test_password',
                    'text' => 'Test post'
                  })

      expect(mock_tempfile).to receive(:close)
      expect(mock_tempfile).to receive(:unlink)

      expect { action.invoke }.to raise_error('Connection error')
    end
  end
end
