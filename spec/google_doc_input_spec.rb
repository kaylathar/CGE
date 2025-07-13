require 'spec_helper'
require 'webmock/rspec'

describe CGE::GoogleDocInput do
  let(:google_doc_input) { CGE::GoogleDocInput.new('google_doc_input_id', "test_input", {}, nil) }
  let(:document_id) { '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms' }
  let(:inputs) { { 'document_id' => document_id } }
  let(:inputs_with_credentials) do
    { 'document_id' => document_id, 'credentials_path' => '/path/to/credentials.json' }
  end

  def create_mock_document(content_text)
    double('document',
           body: double('body', content: [create_paragraph_element(content_text)]))
  end

  def create_paragraph_element(text)
    double('paragraph_element',
           paragraph: double('paragraph', elements: [create_text_element(text)]),
           table: nil)
  end

  def create_text_element(text)
    double('text_element',
           text_run: double('text_run', content: text))
  end

  def create_table_element(text)
    double('table_element',
           paragraph: nil,
           table: double('table',
                         table_rows: [
                           double('row',
                                  table_cells: [
                                    double('cell',
                                           content: [create_paragraph_element(text)])
                                  ])
                         ]))
  end

  let(:mock_document) { create_mock_document('Hello World') }

  let(:mock_service) { double('DocsService') }

  before do
    allow(Google::Apis::DocsV1::DocsService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:authorization=)
    allow(mock_service).to receive(:get_document).with(document_id).and_return(mock_document)
    allow(Google::Auth).to receive(:get_application_default).and_return(double('credentials'))
  end


  it 'should fetch and set document content when processed' do
    mock_graph = double('CommandGraph')
    google_doc_input.execute(inputs, nil, mock_graph)
    expect(google_doc_input.content).to eq('Hello World')
  end

  it 'should raise an error when document_id is not provided' do
    mock_graph = double('CommandGraph')
    expect { google_doc_input.execute({}, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Required input document_id missing/)
  end

  it 'should raise an error when document_id is not a string' do
    mock_graph = double('CommandGraph')
    expect { google_doc_input.execute({ 'document_id' => 123 }, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input document_id/)
  end

  it 'should handle documents with tables' do
    table_document = double('document',
                            body: double('body', content: [create_table_element('Table Content')]))

    allow(mock_service).to receive(:get_document).with(document_id).and_return(table_document)

    mock_graph = double('CommandGraph')
    google_doc_input.execute(inputs, nil, mock_graph)
    expect(google_doc_input.content).to eq('Table Content')
  end

  it 'should handle empty documents' do
    empty_document = double('document', body: double('body', content: nil))
    allow(mock_service).to receive(:get_document).with(document_id).and_return(empty_document)

    mock_graph = double('CommandGraph')
    google_doc_input.execute(inputs, nil, mock_graph)
    expect(google_doc_input.content).to eq('')
  end

  it 'should handle Google API errors' do
    allow(mock_service).to receive(:get_document).and_raise(Google::Apis::ClientError.new('Not found'))

    mock_graph = double('CommandGraph')
    expect { google_doc_input.execute(inputs, nil, mock_graph) }
      .to raise_error(CGE::GoogleDocError, /Google API error/)
  end

  it 'should handle network errors' do
    allow(mock_service).to receive(:get_document).and_raise(StandardError.new('Network error'))

    mock_graph = double('CommandGraph')
    expect { google_doc_input.execute(inputs, nil, mock_graph) }
      .to raise_error(CGE::GoogleDocError, /Failed to fetch document/)
  end

  it 'should validate document_id format' do
    mock_graph = double('CommandGraph')
    expect { google_doc_input.execute({ 'document_id' => 'invalid' }, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input document_id/)
  end

  it 'should validate credentials_path exists' do
    mock_graph = double('CommandGraph')
    expect { google_doc_input.execute({ 'document_id' => document_id, 'credentials_path' => '/nonexistent/path' }, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input credentials_path/)
  end

  it 'should use service account credentials when credentials_path is provided' do
    mock_credentials = double('service_account_credentials')
    mock_file = double('file')
    
    allow(File).to receive(:exist?).with('/path/to/credentials.json').and_return(true)
    allow(File).to receive(:open).with('/path/to/credentials.json').and_return(mock_file)
    expect(Google::Auth::ServiceAccountCredentials).to receive(:make_creds)
      .with(json_key_io: mock_file, scope: ['https://www.googleapis.com/auth/documents.readonly'])
      .and_return(mock_credentials)

    mock_graph = double('CommandGraph')
    google_doc_input.execute(inputs_with_credentials, nil, mock_graph)
    expect(google_doc_input.content).to eq('Hello World')
  end
end