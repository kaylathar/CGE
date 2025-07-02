# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../lib/cge/actions/reddit_post_action'

RSpec.describe CGE::RedditPostAction do
  let(:action) { described_class.new('reddit_id', 'test_reddit', {}, nil, nil, nil) }

  before do
    WebMock.enable!
    
    # Mock Reddit OAuth
    stub_request(:post, 'https://www.reddit.com/api/v1/access_token')
      .to_return(status: 200, body: { access_token: 'test_token' }.to_json)
    
    # Mock Reddit post submission
    stub_request(:post, 'https://oauth.reddit.com/api/submit')
      .to_return(status: 200, body: {
        json: {
          errors: [],
          data: {
            url: 'https://reddit.com/r/test/comments/123/test_post'
          }
        }
      }.to_json)
  end

  after do
    WebMock.disable!
  end

  describe '#invoke' do
    before do
      action.send(:process_inputs, {
        'client_id' => 'test_client_id',
        'client_secret' => 'test_client_secret',
        'username' => 'test_user',
        'password' => 'test_password',
        'subreddit' => 'test',
        'title' => 'Test Post Title',
        'text' => 'This is a test post from CGE'
      })
    end

    it 'authenticates with Reddit and creates a post' do
      action.invoke
      
      expect(WebMock).to have_requested(:post, 'https://www.reddit.com/api/v1/access_token')
        .with(headers: { 'Authorization' => /Basic/ })
      
      expect(WebMock).to have_requested(:post, 'https://oauth.reddit.com/api/submit')
        .with(headers: { 'Authorization' => 'Bearer test_token' })
    end

    it 'sends correct post data' do
      action.invoke
      
      expect(WebMock).to have_requested(:post, 'https://oauth.reddit.com/api/submit')
        .with { |req|
          body = URI.decode_www_form(req.body).to_h
          body['sr'] == 'test' &&
          body['title'] == 'Test Post Title' &&
          body['text'] == 'This is a test post from CGE' &&
          body['kind'] == 'self'
        }
    end
  end

  describe 'input validation' do
    it 'requires client_id input' do
      expect { action.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input client_id/)
    end

    it 'requires client_secret input' do
      expect { 
        action.send(:process_inputs, { 'client_id' => 'test' }) 
      }.to raise_error(CGE::InputError, /Required input client_secret/)
    end

    it 'validates subreddit does not start with r/' do
      expect { 
        action.send(:process_inputs, {
          'client_id' => 'test',
          'client_secret' => 'test',
          'username' => 'test',
          'password' => 'test',
          'subreddit' => 'r/test',
          'title' => 'test',
          'text' => 'test'
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates title length' do
      expect { 
        action.send(:process_inputs, {
          'client_id' => 'test',
          'client_secret' => 'test',
          'username' => 'test',
          'password' => 'test',
          'subreddit' => 'test',
          'title' => 'x' * 301,
          'text' => 'test'
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates kind is valid' do
      expect { 
        action.send(:process_inputs, {
          'client_id' => 'test',
          'client_secret' => 'test',
          'username' => 'test',
          'password' => 'test',
          'subreddit' => 'test',
          'title' => 'test',
          'text' => 'test',
          'kind' => 'invalid'
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid inputs' do
      expect { 
        action.send(:process_inputs, {
          'client_id' => 'test_client_id',
          'client_secret' => 'test_client_secret',
          'username' => 'test_user',
          'password' => 'test_password',
          'subreddit' => 'test',
          'title' => 'Test Post Title',
          'text' => 'This is a test post'
        }) 
      }.not_to raise_error
    end
  end

  describe 'error handling' do
    it 'raises error on authentication failure' do
      stub_request(:post, 'https://www.reddit.com/api/v1/access_token')
        .to_return(status: 401, body: 'Unauthorized')
      
      action.send(:process_inputs, {
        'client_id' => 'test_client_id',
        'client_secret' => 'test_client_secret',
        'username' => 'test_user',
        'password' => 'test_password',
        'subreddit' => 'test',
        'title' => 'Test Post Title',
        'text' => 'This is a test post'
      })
      
      expect { action.invoke }.to raise_error(/Reddit authentication failed/)
    end

    it 'raises error on API errors' do
      stub_request(:post, 'https://oauth.reddit.com/api/submit')
        .to_return(status: 200, body: {
          json: {
            errors: [['SUBREDDIT_NOEXIST', 'that subreddit does not exist', 'sr']]
          }
        }.to_json)
      
      action.send(:process_inputs, {
        'client_id' => 'test_client_id',
        'client_secret' => 'test_client_secret',
        'username' => 'test_user',
        'password' => 'test_password',
        'subreddit' => 'nonexistent',
        'title' => 'Test Post Title',
        'text' => 'This is a test post'
      })
      
      expect { action.invoke }.to raise_error(/Reddit API error/)
    end
  end
end