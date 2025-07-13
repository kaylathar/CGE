require 'spec_helper'
require 'webmock/rspec'

describe CGE::GoogleSheetInput do
  let(:google_sheet_input) { CGE::GoogleSheetInput.new('google_sheet_input_id', "test_input", {}, nil) }
  let(:spreadsheet_id) { '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms' }
  let(:inputs) { { 'spreadsheet_id' => spreadsheet_id } }
  let(:inputs_with_credentials) do
    { 'spreadsheet_id' => spreadsheet_id, 'credentials_path' => '/path/to/credentials.json' }
  end
  let(:inputs_with_range) do
    { 'spreadsheet_id' => spreadsheet_id, 'range' => 'A1:B5' }
  end

  let(:mock_response) do
    double('response', values: [
      ['Name', 'Age'],
      ['John', '25'],
      ['Jane', '30']
    ])
  end

  let(:mock_service) { double('SheetsService') }

  before do
    allow(Google::Apis::SheetsV4::SheetsService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:authorization=)
    allow(mock_service).to receive(:get_spreadsheet_values).and_return(mock_response)
    allow(Google::Auth).to receive(:get_application_default).and_return(double('credentials'))
  end

  it 'should fetch and set spreadsheet content when processed' do
    mock_graph = double('CommandGraph')
    google_sheet_input.execute(inputs, nil, mock_graph)
    expect(google_sheet_input.content).to eq("Name\tAge\nJohn\t25\nJane\t30")
  end

  it 'should use custom range when provided' do
    expect(mock_service).to receive(:get_spreadsheet_values)
      .with(spreadsheet_id, 'A1:B5')
      .and_return(mock_response)

    mock_graph = double('CommandGraph')
    google_sheet_input.execute(inputs_with_range, nil, mock_graph)
    expect(google_sheet_input.content).to eq("Name\tAge\nJohn\t25\nJane\t30")
  end

  it 'should use default range A:ZZ when no range provided' do
    expect(mock_service).to receive(:get_spreadsheet_values)
      .with(spreadsheet_id, 'A:ZZ')
      .and_return(mock_response)

    mock_graph = double('CommandGraph')
    google_sheet_input.execute(inputs, nil, mock_graph)
  end

  it 'should handle empty spreadsheets' do
    empty_response = double('response', values: nil)
    allow(mock_service).to receive(:get_spreadsheet_values).and_return(empty_response)

    mock_graph = double('CommandGraph')
    google_sheet_input.execute(inputs, nil, mock_graph)
    expect(google_sheet_input.content).to eq('')
  end

  it 'should raise an error when spreadsheet_id is not provided' do
    mock_graph = double('CommandGraph')
    expect { google_sheet_input.execute({}, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Required input spreadsheet_id missing/)
  end

  it 'should validate spreadsheet_id format' do
    mock_graph = double('CommandGraph')
    expect { google_sheet_input.execute({ 'spreadsheet_id' => 'invalid' }, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input spreadsheet_id/)
  end

  it 'should validate credentials_path exists' do
    mock_graph = double('CommandGraph')
    expect { google_sheet_input.execute({ 'spreadsheet_id' => spreadsheet_id, 'credentials_path' => '/nonexistent/path' }, nil, mock_graph) }
      .to raise_error(CGE::InputError, /Bad value for input credentials_path/)
  end

  it 'should handle Google API errors' do
    allow(mock_service).to receive(:get_spreadsheet_values).and_raise(Google::Apis::ClientError.new('Not found'))

    mock_graph = double('CommandGraph')
    expect { google_sheet_input.execute(inputs, nil, mock_graph) }
      .to raise_error(CGE::GoogleSheetError, /Google API error/)
  end

  it 'should handle network errors' do
    allow(mock_service).to receive(:get_spreadsheet_values).and_raise(StandardError.new('Network error'))

    mock_graph = double('CommandGraph')
    expect { google_sheet_input.execute(inputs, nil, mock_graph) }
      .to raise_error(CGE::GoogleSheetError, /Failed to fetch spreadsheet/)
  end

  it 'should use service account credentials when credentials_path is provided' do
    mock_credentials = double('service_account_credentials')
    mock_file = double('file')
    
    allow(File).to receive(:exist?).with('/path/to/credentials.json').and_return(true)
    allow(File).to receive(:open).with('/path/to/credentials.json').and_return(mock_file)
    expect(Google::Auth::ServiceAccountCredentials).to receive(:make_creds)
      .with(json_key_io: mock_file, scope: ['https://www.googleapis.com/auth/spreadsheets.readonly'])
      .and_return(mock_credentials)

    mock_graph = double('CommandGraph')
    google_sheet_input.execute(inputs_with_credentials, nil, mock_graph)
    expect(google_sheet_input.content).to eq("Name\tAge\nJohn\t25\nJane\t30")
  end
end