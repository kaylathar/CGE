require 'spec_helper'
require 'webmock/rspec'

describe DAF::WebInput do
  let(:web_input) { DAF::WebInput.new }
  let(:test_uri) { 'https://example.com/test' }
  let(:options) { { 'uri' => test_uri } }
  let(:html_content) do
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test Page</title>
        <style>body { color: red; }</style>
      </head>
      <body>
        <h1>Hello World</h1>
        <p>This is a test page.</p>
        <script>console.log('test');</script>
      </body>
      </html>
    HTML
  end

  before do
    WebMock.enable!
  end

  after do
    WebMock.disable!
  end

  def stub_successful_request(uri = test_uri, body = html_content)
    stub_request(:get, uri)
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'text/html' })
  end

  it 'should fetch and extract text content from webpage' do
    stub_successful_request
    
    web_input.process(options)
    expect(web_input.content).to include('Hello World')
    expect(web_input.content).to include('This is a test page.')
    expect(web_input.content).not_to include('console.log')
    expect(web_input.content).not_to include('color: red')
  end

  it 'should raise error when uri is not provided' do
    expect { web_input.process({}) }
      .to raise_error(DAF::OptionError, /Required option uri missing/)
  end

  it 'should raise error when uri is empty' do
    expect { web_input.process({ 'uri' => '' }) }
      .to raise_error(DAF::OptionError, /Bad value for option uri/)
  end

  it 'should raise error for invalid URI format' do
    expect { web_input.process({ 'uri' => 'not-a-valid-uri' }) }
      .to raise_error(DAF::OptionError, /Bad value for option uri/)
  end

  it 'should raise error for relative URI' do
    expect { web_input.process({ 'uri' => '/relative/path' }) }
      .to raise_error(DAF::OptionError, /Bad value for option uri/)
  end

  it 'should raise error for unsupported URI scheme' do
    expect { web_input.process({ 'uri' => 'ftp://example.com' }) }
      .to raise_error(DAF::OptionError, /Bad value for option uri/)
  end

  it 'should handle HTTP errors' do
    stub_request(:get, test_uri).to_return(status: 404, body: 'Not Found')
    
    expect { web_input.process(options) }
      .to raise_error(DAF::WebInputError, /HTTP 404/)
  end

  it 'should handle redirects' do
    redirect_uri = 'https://example.com/redirected'
    stub_request(:get, test_uri)
      .to_return(status: 302, headers: { 'Location' => redirect_uri })
    stub_request(:get, redirect_uri)
      .to_return(status: 200, body: html_content)
    
    web_input.process(options)
    expect(web_input.content).to include('Hello World')
  end

  it 'should handle too many redirects' do
    6.times do |i|
      next_uri = "https://example.com/redirect#{i + 1}"
      stub_request(:get, i == 0 ? test_uri : "https://example.com/redirect#{i}")
        .to_return(status: 302, headers: { 'Location' => next_uri })
    end
    
    expect { web_input.process(options) }
      .to raise_error(DAF::WebInputError, /Maximum redirects exceeded/)
  end

  it 'should handle response size limits' do
    large_content_type = { 'Content-Length' => (11 * 1024 * 1024).to_s }
    stub_request(:get, test_uri)
      .to_return(status: 200, body: html_content, headers: large_content_type)
    
    expect { web_input.process(options) }
      .to raise_error(DAF::WebInputError, /Response too large/)
  end

  it 'should handle network errors' do
    stub_request(:get, test_uri).to_raise(SocketError.new('Failed to resolve hostname'))
    
    expect { web_input.process(options) }
      .to raise_error(SocketError)
  end

  it 'should handle timeout errors' do
    stub_request(:get, test_uri).to_timeout
    
    expect { web_input.process(options) }
      .to raise_error(Net::OpenTimeout)
  end

  it 'should use custom timeout when provided' do
    options_with_timeout = options.merge('timeout' => 10)
    stub_successful_request
    
    expect(Net::HTTP).to receive(:start).with(
      'example.com', 443, hash_including(read_timeout: 10, open_timeout: 10)
    ).and_call_original
    
    web_input.process(options_with_timeout)
  end

  it 'should use custom user agent when provided' do
    custom_agent = 'CustomBot/1.0'
    options_with_agent = options.merge('user_agent' => custom_agent)
    
    stub_request(:get, test_uri)
      .with(headers: { 'User-Agent' => custom_agent })
      .to_return(status: 200, body: html_content)
    
    web_input.process(options_with_agent)
  end

  it 'should handle empty HTML content' do
    stub_successful_request(test_uri, '')
    
    web_input.process(options)
    expect(web_input.content).to eq('')
  end

  it 'should handle plain text responses' do
    plain_text = 'This is plain text content.'
    stub_successful_request(test_uri, plain_text)
    
    web_input.process(options)
    expect(web_input.content).to eq(plain_text)
  end

  it 'should normalize whitespace in extracted text' do
    messy_html = '<p>  Multiple   spaces   and\n\nnewlines  </p>'
    stub_successful_request(test_uri, messy_html)
    
    web_input.process(options)
    expect(web_input.content).to include('Multiple spaces and')
    expect(web_input.content).to include('newlines')
    expect(web_input.content.length).to be < 50  # Should be condensed
  end
end