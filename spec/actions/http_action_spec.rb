# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../lib/cge/actions/http_action'

RSpec.describe CGE::HttpAction do
  let(:action) { described_class.new('http_id', 'test_http', {}, nil, nil, nil) }
  let(:test_url) { 'https://api.example.com/test' }

  before do
    WebMock.enable!
  end

  after do
    WebMock.disable!
  end

  describe '#invoke with GET request' do
    before do
      stub_request(:get, test_url)
        .to_return(
          status: 200,
          body: { message: 'success' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      
      action.send(:process_inputs, { 'url' => test_url })
    end

    it 'makes a GET request and processes response' do
      action.invoke
      
      expect(action.status_code).to eq(200)
      expect(action.response_body).to eq('{"message":"success"}')
      expect(action.success).to be(true)
    end

    it 'captures response headers' do
      action.invoke
      
      headers = JSON.parse(action.response_headers)
      expect(headers['content-type']).to include('application/json')
    end
  end

  describe '#invoke with POST request' do
    let(:request_body) { { name: 'test', value: 123 }.to_json }
    
    before do
      stub_request(:post, test_url)
        .with(
          body: request_body,
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(status: 201, body: { id: 456 }.to_json)
      
      action.send(:process_inputs, {
        'url' => test_url,
        'method' => 'POST',
        'body' => request_body
      })
    end

    it 'makes a POST request with body' do
      action.invoke
      
      expect(action.status_code).to eq(201)
      expect(action.response_body).to eq('{"id":456}')
      expect(action.success).to be(true)
    end
  end

  describe '#invoke with custom headers' do
    let(:custom_headers) { { 'Authorization' => 'Bearer token123', 'X-Custom' => 'value' } }
    
    before do
      stub_request(:get, test_url).with { |request| request.headers["X-Custom"] == "value"}
        .to_return(status: 200, body: 'authorized')
      
      action.send(:process_inputs, {
        'url' => test_url,
        'headers' => custom_headers
      })
    end

    it 'includes custom headers in request' do
      action.invoke
      
      expect(action.status_code).to eq(200)
      expect(action.response_body).to eq('authorized')
    end
  end

  describe '#invoke with different HTTP methods' do
    %w[PUT DELETE PATCH HEAD OPTIONS].each do |method|
      it "handles #{method} requests" do
        stub_request(method.downcase.to_sym, test_url)
          .to_return(status: 200, body: 'ok')
        
        action.send(:process_inputs, {
          'url' => test_url,
          'method' => method
        })
        
        action.invoke
        
        expect(action.status_code).to eq(200)
        expect(action.success).to be(true)
      end
    end
  end

  describe 'error handling' do
    it 'handles HTTP errors gracefully' do
      stub_request(:get, test_url)
        .to_return(status: 404, body: 'Not Found')
      
      action.send(:process_inputs, { 'url' => test_url })
      action.invoke
      
      expect(action.status_code).to eq(404)
      expect(action.response_body).to eq('Not Found')
      expect(action.success).to be(false)
    end

    it 'handles server errors' do
      stub_request(:get, test_url)
        .to_return(status: 500, body: 'Internal Server Error')
      
      action.send(:process_inputs, { 'url' => test_url })
      action.invoke
      
      expect(action.status_code).to eq(500)
      expect(action.success).to be(false)
    end
  end

  describe 'input validation' do
    it 'requires url input' do
      expect { action.send(:process_inputs, {}) }.to raise_error(CGE::InputError, /Required input url/)
    end

    it 'validates url format' do
      expect { 
        action.send(:process_inputs, { 'url' => 'invalid-url' }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates HTTP method' do
      expect { 
        action.send(:process_inputs, { 
          'url' => test_url, 
          'method' => 'INVALID' 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'validates timeout is positive' do
      expect { 
        action.send(:process_inputs, { 
          'url' => test_url, 
          'timeout' => 0 
        }) 
      }.to raise_error(CGE::InputError)
    end

    it 'accepts valid HTTP URLs' do
      expect { 
        action.send(:process_inputs, { 'url' => 'http://example.com' }) 
      }.not_to raise_error
    end

    it 'accepts valid HTTPS URLs' do
      expect { 
        action.send(:process_inputs, { 'url' => 'https://example.com' }) 
      }.not_to raise_error
    end

    it 'accepts all valid inputs' do
      expect { 
        action.send(:process_inputs, {
          'url' => test_url,
          'method' => 'POST',
          'headers' => {"Authorization": "Bearer token"},
          'body' => '{"test": true}',
          'content_type' => 'application/json',
          'timeout' => 60,
        }) 
      }.not_to raise_error
    end
  end

  describe 'output attributes' do
    it 'provides access to all output attributes' do
      expect(action).to respond_to(:status_code)
      expect(action).to respond_to(:response_body)
      expect(action).to respond_to(:response_headers)
      expect(action).to respond_to(:success)
    end
  end
end