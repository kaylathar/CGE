require 'spec_helper'
require 'webmock/rspec'

describe DAF::GoogleSheetInput do
  let(:google_sheet_input) { DAF::GoogleSheetInput.new }
  let(:spreadsheet_id) { '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms' }
  let(:options) { { 'spreadsheet_id' => spreadsheet_id } }
  let(:options_with_credentials) do
    { 'spreadsheet_id' => spreadsheet_id, 'credentials_path' => '/path/to/credentials.json' }
  end
  let(:options_with_range) do
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
    google_sheet_input.process(options)
    expect(google_sheet_input.content).to eq("Name\tAge\nJohn\t25\nJane\t30")
  end

  it 'should use custom range when provided' do
    expect(mock_service).to receive(:get_spreadsheet_values)
      .with(spreadsheet_id, 'A1:B5')
      .and_return(mock_response)

    google_sheet_input.process(options_with_range)
    expect(google_sheet_input.content).to eq("Name\tAge\nJohn\t25\nJane\t30")
  end

  it 'should use default range A:ZZ when no range provided' do
    expect(mock_service).to receive(:get_spreadsheet_values)
      .with(spreadsheet_id, 'A:ZZ')
      .and_return(mock_response)

    google_sheet_input.process(options)
  end

  it 'should handle empty spreadsheets' do
    empty_response = double('response', values: nil)
    allow(mock_service).to receive(:get_spreadsheet_values).and_return(empty_response)

    google_sheet_input.process(options)
    expect(google_sheet_input.content).to eq('')
  end

  it 'should raise an error when spreadsheet_id is not provided' do
    expect { google_sheet_input.process({}) }
      .to raise_error(DAF::OptionError, /Required option spreadsheet_id missing/)
  end

  it 'should validate spreadsheet_id format' do
    expect { google_sheet_input.process({ 'spreadsheet_id' => 'invalid' }) }
      .to raise_error(DAF::OptionError, /Bad value for option spreadsheet_id/)
  end

  it 'should validate credentials_path exists' do
    expect { google_sheet_input.process({ 'spreadsheet_id' => spreadsheet_id, 'credentials_path' => '/nonexistent/path' }) }
      .to raise_error(DAF::OptionError, /Bad value for option credentials_path/)
  end

  it 'should handle Google API errors' do
    allow(mock_service).to receive(:get_spreadsheet_values).and_raise(Google::Apis::ClientError.new('Not found'))

    expect { google_sheet_input.process(options) }
      .to raise_error(DAF::GoogleSheetError, /Google API error/)
  end

  it 'should handle network errors' do
    allow(mock_service).to receive(:get_spreadsheet_values).and_raise(StandardError.new('Network error'))

    expect { google_sheet_input.process(options) }
      .to raise_error(DAF::GoogleSheetError, /Failed to fetch spreadsheet/)
  end

  it 'should use service account credentials when credentials_path is provided' do
    mock_credentials = double('service_account_credentials')
    mock_file = double('file')
    
    allow(File).to receive(:exist?).with('/path/to/credentials.json').and_return(true)
    allow(File).to receive(:open).with('/path/to/credentials.json').and_return(mock_file)
    expect(Google::Auth::ServiceAccountCredentials).to receive(:make_creds)
      .with(json_key_io: mock_file, scope: ['https://www.googleapis.com/auth/spreadsheets.readonly'])
      .and_return(mock_credentials)

    google_sheet_input.process(options_with_credentials)
    expect(google_sheet_input.content).to eq("Name\tAge\nJohn\t25\nJane\t30")
  end
end