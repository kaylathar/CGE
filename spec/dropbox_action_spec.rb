require 'spec_helper'

describe CGE::DropboxFileAction do
  before(:each) do
    @inputs = { 'access_token' => 'test_token_123',
                 'file_path' => '/test_file.txt',
                 'content' => 'Test content' }
    @action = CGE::DropboxFileAction.new('dropbox_action_id', 'dropbox_action', {}, nil)
  end

  context 'inputs' do
    it 'has three required inputs' do
      expect { @action.class.required_inputs }.not_to raise_error
      expect(@action.class.required_inputs.length).to eq(3)
    end

    it 'has four inputs total' do
      expect { @action.class.inputs }.not_to raise_error
      expect(@action.class.inputs.length).to eq(4)
    end

    it 'has an access_token input of type String' do
      expect(@action.class.inputs['access_token']).to eq(String)
    end

    it 'has a file_path input of type String' do
      expect(@action.class.inputs['file_path']).to eq(String)
    end

    it 'has a content input of type String' do
      expect(@action.class.inputs['content']).to eq(String)
    end

    it 'has an optional overwrite input of type Object' do
      expect(@action.class.inputs['overwrite']).to eq(Object)
    end
  end

  context 'when execute is called' do
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

      mock_graph = double('CommandGraph')
      @action.execute(@inputs, nil, mock_graph)
    end

    it 'sets correct headers for the request' do
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')

      expect(@request).to receive(:[]=).with('Authorization', 'Bearer test_token_123')
      expect(@request).to receive(:[]=).with('Content-Type', 'application/octet-stream')
      expect(@request).to receive(:[]=).with('Dropbox-API-Arg', kind_of(String))

      mock_graph = double('CommandGraph')
      @action.execute(@inputs, nil, mock_graph)
    end

    it 'sends content as request body' do
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')

      expect(@request).to receive(:body=).with('Test content')

      mock_graph = double('CommandGraph')
      @action.execute(@inputs, nil, mock_graph)
    end

    it 'uses overwrite mode when overwrite is true' do
      @inputs['overwrite'] = true
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')
      
      expect(@request).to receive(:[]=).with('Authorization', kind_of(String))
      expect(@request).to receive(:[]=).with('Content-Type', kind_of(String))
      expect(@request).to receive(:[]=).with('Dropbox-API-Arg', kind_of(String))

      mock_graph = double('CommandGraph')
      @action.execute(@inputs, nil, mock_graph)

      expect(JSON.parse(@request_headers['Dropbox-API-Arg'])).to match(hash_including("mode" => "overwrite"))
    end

    it 'uses add mode when overwrite is false' do
      @inputs['overwrite'] = false
      allow(@response).to receive(:code).and_return('200')
      allow(@response).to receive(:body).and_return('{"path_display": "/test_file.txt"}')

      expect(@request).to receive(:[]=).with('Authorization', kind_of(String))
      expect(@request).to receive(:[]=).with('Content-Type', kind_of(String))
      expect(@request).to receive(:[]=).with('Dropbox-API-Arg', kind_of(String))

      mock_graph = double('CommandGraph')
      @action.execute(@inputs, nil, mock_graph)

      expect(JSON.parse(@request_headers['Dropbox-API-Arg'])).to match(hash_including("mode" => "add"))
    end

    it 'handles API errors gracefully' do
      allow(@response).to receive(:code).and_return('400')
      allow(@response).to receive(:body).and_return('{"error": "Invalid request"}')

      mock_graph = double('CommandGraph')
      expect {@action.execute(@inputs, nil, mock_graph)}.to raise_error(CGE::DropboxFileActionError)
    end

    it 'handles network errors gracefully' do
      allow(@http).to receive(:request).and_raise(StandardError.new('Network error'))

      mock_graph = double('CommandGraph')
      expect {@action.execute(@inputs, nil, mock_graph)}.to raise_error(CGE::DropboxFileActionError)
    end
  end
end
