require 'spec_helper'

describe DAF::DropboxFileAction do
  before(:each) do
    @options = { 'access_token' => 'test_token_123',
                 'file_path' => '/test_file.txt',
                 'content' => 'Test content' }
    @action = DAF::DropboxFileAction.new
  end

  context 'options' do
    it 'has three required options' do
      expect { @action.class.required_options }.not_to raise_error
      expect(@action.class.required_options.length).to eq(3)
    end

    it 'has four options total' do
      expect { @action.class.options }.not_to raise_error
      expect(@action.class.options.length).to eq(4)
    end

    it 'has an access_token option of type String' do
      expect(@action.class.options['access_token']).to eq(String)
    end

    it 'has a file_path option of type String' do
      expect(@action.class.options['file_path']).to eq(String)
    end

    it 'has a content option of type String' do
      expect(@action.class.options['content']).to eq(String)
    end

    it 'has an optional overwrite option of type Object' do
      expect(@action.class.options['overwrite']).to eq(Object)
    end
  end

  context 'when activate is called' do
    before(:each) do
      @http = double('Net::HTTP')
      @response = double('Net::HTTPResponse')
      @request = double('Net::HTTP::Post')
      @request_headers = {}

      allow(Net::HTTP).to receive(:new).and_return(@http)
      allow(@http).to receive(:use_ssl=)
      allow(Net::HTTP::Post).to receive(:new).and_return(@request)
      allow(@request).to receive(:[]=) do |key,value|
        @request_headers[key] = value
      end
      allow(@request).to receive(:body=)
      allow(@http).to receive(:request).and_return(@response)
    end

    it 'makes a POST request to Dropbox API' do
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')

      expect(Net::HTTP).to receive(:new).with('content.dropboxapi.com', 443)
      expect(@http).to receive(:use_ssl=).with(true)

      @action.activate(@options)
    end

    it 'sets correct headers for the request' do
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')

      expect(@request).to receive(:[]=).with('Authorization', 'Bearer test_token_123')
      expect(@request).to receive(:[]=).with('Content-Type', 'application/octet-stream')
      expect(@request).to receive(:[]=).with('Dropbox-API-Arg', kind_of(String))

      @action.activate(@options)
    end

    it 'sends content as request body' do
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')

      expect(@request).to receive(:body=).with('Test content')

      @action.activate(@options)
    end

    it 'uses overwrite mode when overwrite is true' do
      @options['overwrite'] = true
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')
      
      expect(@request).to receive(:[]=).with('Authorization', kind_of(String))
      expect(@request).to receive(:[]=).with('Content-Type', kind_of(String))
      expect(@request).to receive(:[]=).with('Dropbox-API-Arg', kind_of(String))

      @action.activate(@options)

      expect(JSON.parse(@request_headers['Dropbox-API-Arg'])).to match(hash_including("mode" => "overwrite"))
    end

    it 'uses add mode when overwrite is false' do
      @options['overwrite'] = false
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')

      expect(@request).to receive(:[]=).with('Authorization', kind_of(String))
      expect(@request).to receive(:[]=).with('Content-Type', kind_of(String))
      expect(@request).to receive(:[]=).with('Dropbox-API-Arg', kind_of(String))

      @action.activate(@options)

      expect(JSON.parse(@request_headers['Dropbox-API-Arg'])).to match(hash_including("mode" => "add"))
    end

    it 'handles API errors gracefully' do
      allow(@response).to receive(:code).and_return('400')
      allow(@response).to receive(:body).and_return('{"error": "Invalid request"}')

      expect {@action.activate(@options) {}}.to raise_error(DAF::DropboxFileActionError)
    end

    it 'handles network errors gracefully' do
      allow(@http).to receive(:request).and_raise(StandardError.new('Network error'))

      expect {@action.activate(@options) {}}.to raise_error(DAF::DropboxFileActionError)
    end
  end
end
